import Foundation
import NaturalLanguage

enum EntrySearchScope: String, CaseIterable, Hashable, Identifiable, Sendable {
    case all
    case achievements
    case standup
    case gratitude

    var id: Self {
        self
    }

    var displayName: String {
        switch self {
        case .all:
            return "All"
        case .achievements:
            return "Achievements"
        case .standup:
            return "Standup"
        case .gratitude:
            return "Gratitude"
        }
    }

    var fields: [EntryField] {
        switch self {
        case .all:
            return EntryField.allCases
        case .achievements:
            return [.achievements]
        case .standup:
            return [.standup]
        case .gratitude:
            return [.gratitude]
        }
    }
}

struct EntrySearchResult: Identifiable, Equatable, Sendable {
    let dateKey: String
    let field: EntryField
    let sourceText: String
    let snippet: String
    let matchedTerms: [String]
    let score: Int

    var id: String {
        "\(dateKey)-\(field.rawValue)"
    }
}

struct EntrySearchIndex: Sendable {
    private static let stopWords: Set<String> = [
        "a", "an", "and", "are", "at", "be", "been", "being", "but", "by",
        "for", "from", "in", "is", "of", "on", "or", "the", "to", "was",
        "were", "with"
    ]

    private var entriesByDateKey: [String: IndexedEntry] = [:]
    private(set) var activityByDateKey: [String: EntryActivity] = [:]

    init(entries: [DailyEntry] = []) {
        replaceAll(with: entries)
    }

    mutating func replaceAll(with entries: [DailyEntry]) {
        entriesByDateKey.removeAll(keepingCapacity: true)
        activityByDateKey.removeAll(keepingCapacity: true)

        for entry in entries {
            if Task.isCancelled {
                break
            }
            update(entry)
        }
    }

    mutating func update(_ entry: DailyEntry) {
        guard !entry.isEmpty else {
            entriesByDateKey.removeValue(forKey: entry.dateKey)
            activityByDateKey.removeValue(forKey: entry.dateKey)
            return
        }

        entriesByDateKey[entry.dateKey] = IndexedEntry(entry: entry)
        activityByDateKey[entry.dateKey] = entry.activity
    }

    func search(
        query: String,
        scope: EntrySearchScope = .all,
        limit: Int? = 50
    ) -> [EntrySearchResult] {
        if let limit, limit <= 0 {
            return []
        }

        let isBlankQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let allQueryTokens = LexicalNormalizer.tokens(in: query)
        if allQueryTokens.isEmpty {
            guard isBlankQuery else {
                return []
            }
            return applyingLimit(
                to: browseResults(scope: scope).sorted(by: resultSort),
                limit: limit
            )
        }

        let contentTokens = allQueryTokens.filter { !Self.stopWords.contains($0.folded) }
        let queryTokens = deduplicated(contentTokens.isEmpty ? allQueryTokens : contentTokens)

        var results: [EntrySearchResult] = []

        for entry in entriesByDateKey.values {
            if Task.isCancelled {
                return []
            }

            for field in scope.fields {
                guard
                    let section = entry.sections[field],
                    let match = evaluate(
                        section: section,
                        queryTokens: queryTokens,
                        allQueryTokens: allQueryTokens
                    )
                else {
                    continue
                }

                let matchedTerms = uniqueMatchedTerms(from: match.tokenMatches)
                let anchorToken = match.tokenMatches.min(by: {
                    $0.token.ordinal < $1.token.ordinal
                })?.token

                results.append(EntrySearchResult(
                    dateKey: entry.dateKey,
                    field: field,
                    sourceText: section.text,
                    snippet: Self.makeSnippet(
                        from: section.text,
                        aroundCharacterOffset: anchorToken?.characterOffset ?? 0
                    ),
                    matchedTerms: matchedTerms,
                    score: match.score
                ))
            }
        }

        return applyingLimit(to: results.sorted(by: resultSort), limit: limit)
    }

    private func browseResults(scope: EntrySearchScope) -> [EntrySearchResult] {
        var results: [EntrySearchResult] = []

        for entry in entriesByDateKey.values {
            if Task.isCancelled {
                return []
            }

            for field in scope.fields {
                guard let section = entry.sections[field] else {
                    continue
                }

                results.append(EntrySearchResult(
                    dateKey: entry.dateKey,
                    field: field,
                    sourceText: section.text,
                    snippet: Self.makeSnippet(
                        from: section.text,
                        aroundCharacterOffset: section.tokens.first?.characterOffset ?? 0
                    ),
                    matchedTerms: [],
                    score: 0
                ))
            }
        }

        return results
    }

    private func applyingLimit(
        to results: [EntrySearchResult],
        limit: Int?
    ) -> [EntrySearchResult] {
        guard let limit else {
            return results
        }
        return Array(results.prefix(limit))
    }

    private func evaluate(
        section: IndexedSection,
        queryTokens: [LexicalToken],
        allQueryTokens: [LexicalToken]
    ) -> SectionMatch? {
        let exactPhraseMatches = exactPhraseMatches(
            sectionTokens: section.tokens,
            allQueryTokens: allQueryTokens,
            contentQueryTokens: queryTokens
        )
        guard let tokenMatches = exactPhraseMatches ?? assignDistinctMatches(
            queryTokens: queryTokens,
            sectionTokens: section.tokens
        ) else {
            return nil
        }

        let isExactPhrase = exactPhraseMatches != nil
        let minimumQuality = tokenMatches.map(\.quality.rawValue).min() ?? 0
        let tier = isExactPhrase ? 4 : minimumQuality
        let exactCount = tokenMatches.filter { $0.quality == .exact }.count
        let normalizedCount = tokenMatches.filter { $0.quality == .normalized }.count
        let editPenalty = tokenMatches.reduce(0) { $0 + $1.editDistance * 100 }
        let ordinals = tokenMatches.map(\.token.ordinal)
        let span = (ordinals.max() ?? 0) - (ordinals.min() ?? 0)
        let proximityBonus = max(0, 1_000 - span * 10)

        let score =
            tier * 1_000_000
            + exactCount * 10_000
            + normalizedCount * 1_000
            + proximityBonus
            - editPenalty

        return SectionMatch(tokenMatches: tokenMatches, score: score)
    }

    private func assignDistinctMatches(
        queryTokens: [LexicalToken],
        sectionTokens: [LexicalToken]
    ) -> [TokenMatch]? {
        guard queryTokens.count <= sectionTokens.count else {
            return nil
        }

        let candidateSets = queryTokens.map { queryToken in
            candidateMatches(for: queryToken, in: sectionTokens)
                .sorted(by: candidateSort)
        }
        guard candidateSets.allSatisfy({ !$0.isEmpty }) else {
            return nil
        }

        let nonFuzzyCandidateSets = candidateSets.map {
            $0.filter { $0.quality != .fuzzy }
        }
        if let matches = maximumCardinalityMatches(
            candidateSets: nonFuzzyCandidateSets,
            queryTokens: queryTokens
        ) {
            return matches
        }

        let fuzzyQueryIndices = queryTokens.count == 1
            ? Array(candidateSets.indices)
            : candidateSets.indices.filter { queryIndex in
                candidateSets[queryIndex].contains { $0.quality == .fuzzy }
            }
        var bestMatches: [TokenMatch]?
        var bestScore = Int.min

        for fuzzyQueryIndex in fuzzyQueryIndices {
            var scenarioCandidateSets = nonFuzzyCandidateSets
            scenarioCandidateSets[fuzzyQueryIndex] = candidateSets[fuzzyQueryIndex]

            guard let matches = maximumCardinalityMatches(
                candidateSets: scenarioCandidateSets,
                queryTokens: queryTokens
            ) else {
                continue
            }

            let score = assignmentScore(matches)
            if score > bestScore {
                bestScore = score
                bestMatches = matches
            }
        }

        return bestMatches
    }

    private func maximumCardinalityMatches(
        candidateSets: [[TokenMatch]],
        queryTokens: [LexicalToken]
    ) -> [TokenMatch]? {
        guard candidateSets.allSatisfy({ !$0.isEmpty }) else {
            return nil
        }

        let queryOrder = candidateSets.indices.sorted { lhs, rhs in
            if candidateSets[lhs].count != candidateSets[rhs].count {
                return candidateSets[lhs].count < candidateSets[rhs].count
            }
            if queryTokens[lhs].folded != queryTokens[rhs].folded {
                return queryTokens[lhs].folded < queryTokens[rhs].folded
            }
            return lhs < rhs
        }
        var tokenAssignments: [Int: Int] = [:]
        var queryAssignments: [Int: TokenMatch] = [:]

        func augment(_ queryIndex: Int, visitedOrdinals: inout Set<Int>) -> Bool {
            if Task.isCancelled {
                return false
            }

            for candidate in candidateSets[queryIndex] {
                let ordinal = candidate.token.ordinal
                guard visitedOrdinals.insert(ordinal).inserted else {
                    continue
                }

                if let assignedQueryIndex = tokenAssignments[ordinal] {
                    if augment(assignedQueryIndex, visitedOrdinals: &visitedOrdinals) {
                        tokenAssignments[ordinal] = queryIndex
                        queryAssignments[queryIndex] = candidate
                        return true
                    }
                } else {
                    tokenAssignments[ordinal] = queryIndex
                    queryAssignments[queryIndex] = candidate
                    return true
                }
            }

            return false
        }

        for queryIndex in queryOrder {
            var visitedOrdinals: Set<Int> = []
            guard augment(queryIndex, visitedOrdinals: &visitedOrdinals) else {
                return nil
            }
        }

        return queryTokens.indices.compactMap { queryAssignments[$0] }
    }

    private func candidateMatches(
        for queryToken: LexicalToken,
        in sectionTokens: [LexicalToken]
    ) -> [TokenMatch] {
        sectionTokens.compactMap { token in
            if token.folded == queryToken.folded {
                return TokenMatch(token: token, quality: .exact, editDistance: 0)
            }
            if !token.forms.isDisjoint(with: queryToken.forms) {
                return TokenMatch(token: token, quality: .normalized, editDistance: 0)
            }
            if let distance = fuzzyDistance(from: queryToken, to: token) {
                return TokenMatch(token: token, quality: .fuzzy, editDistance: distance)
            }
            return nil
        }
    }

    private func candidateSort(_ lhs: TokenMatch, _ rhs: TokenMatch) -> Bool {
        if lhs.quality.rawValue != rhs.quality.rawValue {
            return lhs.quality.rawValue > rhs.quality.rawValue
        }
        if lhs.editDistance != rhs.editDistance {
            return lhs.editDistance < rhs.editDistance
        }
        return lhs.token.ordinal < rhs.token.ordinal
    }

    private func assignmentScore(_ matches: [TokenMatch]) -> Int {
        let minimumQuality = matches.map(\.quality.rawValue).min() ?? 0
        let exactCount = matches.filter { $0.quality == .exact }.count
        let normalizedCount = matches.filter { $0.quality == .normalized }.count
        let editPenalty = matches.reduce(0) { $0 + $1.editDistance * 100 }
        let ordinals = matches.map(\.token.ordinal)
        let span = (ordinals.max() ?? 0) - (ordinals.min() ?? 0)
        let proximityBonus = max(0, 1_000 - span * 10)

        return minimumQuality * 1_000_000
            + exactCount * 10_000
            + normalizedCount * 1_000
            + proximityBonus
            - editPenalty
    }

    private func fuzzyDistance(
        from queryToken: LexicalToken,
        to sectionToken: LexicalToken
    ) -> Int? {
        var bestDistance: Int?

        for queryForm in queryToken.forms where queryForm.count >= 4 {
            for sectionForm in sectionToken.forms where sectionForm.count >= 4 {
                let allowedDistance = Self.maximumEditDistance(
                    lhsLength: queryForm.count,
                    rhsLength: sectionForm.count
                )
                guard allowedDistance > 0 else {
                    continue
                }

                guard abs(queryForm.count - sectionForm.count) <= allowedDistance else {
                    continue
                }

                guard let distance = DamerauLevenshtein.distance(
                    queryForm,
                    sectionForm,
                    maximum: allowedDistance
                ) else {
                    continue
                }

                bestDistance = min(bestDistance ?? distance, distance)
            }
        }

        return bestDistance
    }

    private func deduplicated(_ tokens: [LexicalToken]) -> [LexicalToken] {
        var seen: Set<String> = []
        return tokens.filter { token in
            let key = token.forms.min(by: {
                $0.count == $1.count ? $0 < $1 : $0.count < $1.count
            }) ?? token.folded
            return seen.insert(key).inserted
        }
    }

    private func uniqueMatchedTerms(from matches: [TokenMatch]) -> [String] {
        var seen: Set<String> = []
        return matches.compactMap { match in
            let key = LexicalNormalizer.fold(match.token.original)
            return seen.insert(key).inserted ? match.token.original : nil
        }
    }

    private func exactPhraseMatches(
        sectionTokens: [LexicalToken],
        allQueryTokens: [LexicalToken],
        contentQueryTokens: [LexicalToken]
    ) -> [TokenMatch]? {
        guard
            !allQueryTokens.isEmpty,
            allQueryTokens.count <= sectionTokens.count
        else {
            return nil
        }

        let querySequence = allQueryTokens.map(\.folded)
        for startIndex in 0...(sectionTokens.count - allQueryTokens.count) {
            let endIndex = startIndex + allQueryTokens.count
            let phraseTokens = Array(sectionTokens[startIndex..<endIndex])

            guard phraseTokens.map(\.folded) == querySequence else {
                continue
            }

            var usedOrdinals: Set<Int> = []
            var matches: [TokenMatch] = []
            for queryToken in contentQueryTokens {
                guard let token = phraseTokens.first(where: {
                    !usedOrdinals.contains($0.ordinal)
                        && $0.folded == queryToken.folded
                }) else {
                    matches = []
                    break
                }
                usedOrdinals.insert(token.ordinal)
                matches.append(TokenMatch(
                    token: token,
                    quality: .exact,
                    editDistance: 0
                ))
            }

            if matches.count == contentQueryTokens.count {
                return matches
            }
        }

        return nil
    }

    private func resultSort(_ lhs: EntrySearchResult, _ rhs: EntrySearchResult) -> Bool {
        if lhs.score != rhs.score {
            return lhs.score > rhs.score
        }
        if lhs.dateKey != rhs.dateKey {
            return lhs.dateKey > rhs.dateKey
        }
        return fieldSortOrder(lhs.field) < fieldSortOrder(rhs.field)
    }

    private func fieldSortOrder(_ field: EntryField) -> Int {
        switch field {
        case .standup:
            return 0
        case .achievements:
            return 1
        case .gratitude:
            return 2
        }
    }

    private static func maximumEditDistance(lhsLength: Int, rhsLength: Int) -> Int {
        let shorterLength = min(lhsLength, rhsLength)
        let longerLength = max(lhsLength, rhsLength)

        guard shorterLength >= 4 else {
            return 0
        }
        return longerLength >= 8 ? 2 : 1
    }

    private static func makeSnippet(
        from source: String,
        aroundCharacterOffset anchorOffset: Int,
        maximumLength: Int = 170
    ) -> String {
        guard source.count > maximumLength else {
            return source
                .split(whereSeparator: \.isWhitespace)
                .joined(separator: " ")
        }

        var startOffset = max(0, min(anchorOffset, source.count) - 55)
        let endOffset = min(source.count, startOffset + maximumLength)
        if endOffset - startOffset < maximumLength {
            startOffset = max(0, endOffset - maximumLength)
        }

        let startIndex = source.index(source.startIndex, offsetBy: startOffset)
        let endIndex = source.index(source.startIndex, offsetBy: endOffset)
        var fragment = source[startIndex..<endIndex]
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")

        if startOffset > 0, let firstSpace = fragment.firstIndex(where: \.isWhitespace) {
            fragment = String(fragment[fragment.index(after: firstSpace)...])
        }
        if endOffset < source.count, let lastSpace = fragment.lastIndex(where: \.isWhitespace) {
            fragment = String(fragment[..<lastSpace])
        }

        let prefix = startOffset > 0 ? "…" : ""
        let suffix = endOffset < source.count ? "…" : ""
        return prefix + fragment.trimmingCharacters(in: .whitespacesAndNewlines) + suffix
    }
}

private extension EntrySearchIndex {
    struct IndexedEntry: Sendable {
        let dateKey: String
        let sections: [EntryField: IndexedSection]

        init(entry: DailyEntry) {
            dateKey = entry.dateKey
            sections = Dictionary(uniqueKeysWithValues: EntryField.allCases.compactMap { field in
                let text = field.text(in: entry)
                guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    return nil
                }
                return (field, IndexedSection(text: text))
            })
        }
    }

    struct IndexedSection: Sendable {
        let text: String
        let tokens: [LexicalToken]

        init(text: String) {
            self.text = text
            self.tokens = LexicalNormalizer.tokens(in: text)
        }
    }

    struct SectionMatch {
        let tokenMatches: [TokenMatch]
        let score: Int
    }

    struct TokenMatch {
        let token: LexicalToken
        let quality: MatchQuality
        let editDistance: Int
    }

    enum MatchQuality: Int {
        case fuzzy = 1
        case normalized = 2
        case exact = 3
    }
}

private struct LexicalToken: Sendable {
    let original: String
    let folded: String
    let forms: Set<String>
    let ordinal: Int
    let characterOffset: Int
}

private enum LexicalNormalizer {
    static func tokens(in text: String) -> [LexicalToken] {
        guard !text.isEmpty else {
            return []
        }

        let tagger = NLTagger(tagSchemes: [.lemma])
        tagger.string = text
        let fullRange = text.startIndex..<text.endIndex
        tagger.setLanguage(.english, range: fullRange)

        var tokens: [LexicalToken] = []
        tagger.enumerateTags(
            in: fullRange,
            unit: .word,
            scheme: .lemma,
            options: [.omitPunctuation, .omitWhitespace]
        ) { tag, tokenRange in
            appendToken(
                String(text[tokenRange]),
                lemma: tag?.rawValue,
                characterOffset: text.distance(
                    from: text.startIndex,
                    to: tokenRange.lowerBound
                ),
                to: &tokens
            )
            return true
        }

        if tokens.isEmpty {
            text.enumerateSubstrings(
                in: fullRange,
                options: [.byWords, .localized]
            ) { substring, substringRange, _, _ in
                guard let substring else {
                    return
                }
                appendToken(
                    substring,
                    lemma: nil,
                    characterOffset: text.distance(
                        from: text.startIndex,
                        to: substringRange.lowerBound
                    ),
                    to: &tokens
                )
            }
        }

        return tokens
    }

    static func fold(_ value: String) -> String {
        value
            .folding(
                options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                locale: Locale(identifier: "en_US_POSIX")
            )
            .lowercased()
    }

    private static func appendToken(
        _ original: String,
        lemma: String?,
        characterOffset: Int,
        to tokens: inout [LexicalToken]
    ) {
        let folded = fold(original)
        guard folded.rangeOfCharacter(from: .alphanumerics) != nil else {
            return
        }

        var forms: Set<String> = [folded]
        if let lemma {
            let foldedLemma = fold(lemma)
            if foldedLemma.rangeOfCharacter(from: .alphanumerics) != nil {
                forms.insert(foldedLemma)
            } else {
                forms.formUnion(fallbackForms(for: folded))
            }
        } else {
            forms.formUnion(fallbackForms(for: folded))
        }
        if let acronymPluralBase = acronymPluralBase(for: original) {
            forms.insert(acronymPluralBase)
        }

        tokens.append(LexicalToken(
            original: original,
            folded: folded,
            forms: forms,
            ordinal: tokens.count,
            characterOffset: characterOffset
        ))
    }

    private static func acronymPluralBase(for word: String) -> String? {
        guard word.last == "s" else {
            return nil
        }

        let base = word.dropLast()
        guard
            base.count >= 2,
            base.allSatisfy({ $0.isUppercase || $0.isNumber })
        else {
            return nil
        }

        return fold(String(base))
    }

    private static func fallbackForms(for word: String) -> Set<String> {
        var forms: Set<String> = [word]

        if word.count > 4, word.hasSuffix("ies") {
            forms.insert(String(word.dropLast(3)) + "y")
        } else if word.count > 4,
                  ["sses", "ches", "shes", "xes", "zes", "oes"].contains(where: word.hasSuffix) {
            forms.insert(String(word.dropLast(2)))
        } else if word.count > 3,
                  word.hasSuffix("s"),
                  !word.hasSuffix("ss"),
                  !word.hasSuffix("us"),
                  !word.hasSuffix("is") {
            forms.insert(String(word.dropLast()))
        }

        if word.count > 5, word.hasSuffix("ing") {
            addInflectionStem(String(word.dropLast(3)), to: &forms)
        }

        if word.count > 4, word.hasSuffix("ied") {
            forms.insert(String(word.dropLast(3)) + "y")
        } else if word.count > 4, word.hasSuffix("ed") {
            addInflectionStem(String(word.dropLast(2)), to: &forms)
        }

        return forms
    }

    private static func addInflectionStem(_ stem: String, to forms: inout Set<String>) {
        guard !stem.isEmpty else {
            return
        }

        if stem.count > 2 {
            let characters = Array(stem)
            if characters[characters.count - 1] == characters[characters.count - 2] {
                forms.insert(String(characters.dropLast()))
                return
            }
        }

        if stem.count <= 3,
           let lastCharacter = stem.last,
           !["x", "w", "y"].contains(String(lastCharacter)) {
            forms.insert(stem + "e")
        } else {
            forms.insert(stem)
        }
    }
}

private enum DamerauLevenshtein {
    static func distance(
        _ lhs: String,
        _ rhs: String,
        maximum: Int
    ) -> Int? {
        let left = Array(lhs)
        let right = Array(rhs)
        guard abs(left.count - right.count) <= maximum else {
            return nil
        }

        if left.isEmpty || right.isEmpty {
            let distance = max(left.count, right.count)
            return distance <= maximum ? distance : nil
        }

        let rowCount = left.count + 1
        let columnCount = right.count + 1
        let sentinel = maximum + 1
        var matrix = Array(repeating: sentinel, count: rowCount * columnCount)

        func index(_ row: Int, _ column: Int) -> Int {
            row * columnCount + column
        }

        for row in 0...min(left.count, maximum) {
            matrix[index(row, 0)] = row
        }
        for column in 0...min(right.count, maximum) {
            matrix[index(0, column)] = column
        }

        for row in 1..<rowCount {
            let firstColumn = max(1, row - maximum)
            let lastColumn = min(right.count, row + maximum)
            guard firstColumn <= lastColumn else {
                return nil
            }

            var rowMinimum = sentinel
            for column in firstColumn...lastColumn {
                let substitutionCost = left[row - 1] == right[column - 1] ? 0 : 1
                var value = min(
                    min(
                        matrix[index(row - 1, column)] + 1,
                        matrix[index(row, column - 1)] + 1
                    ),
                    matrix[index(row - 1, column - 1)] + substitutionCost
                )

                if row > 1,
                   column > 1,
                   left[row - 1] == right[column - 2],
                   left[row - 2] == right[column - 1] {
                    value = min(value, matrix[index(row - 2, column - 2)] + 1)
                }

                matrix[index(row, column)] = value
                rowMinimum = min(rowMinimum, value)
            }

            if rowMinimum > maximum {
                return nil
            }
        }

        let distance = matrix[index(left.count, right.count)]
        return distance <= maximum ? distance : nil
    }
}
