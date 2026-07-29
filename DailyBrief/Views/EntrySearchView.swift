import SwiftUI

struct EntrySearchView: View {
    @ObservedObject var viewModel: DailyBriefViewModel
    let isActive: Bool
    var onClose: () -> Void
    var onOpenResult: (EntrySearchResult) -> Void

    @FocusState private var isSearchFieldFocused: Bool
    @AccessibilityFocusState private var accessibilityFocusedResultID: EntrySearchResult.ID?
    @State private var selectedResultID: EntrySearchResult.ID?

    var body: some View {
        VStack(spacing: 14) {
            searchHeader
            scopeFilters
            searchContent

            Divider()
                .overlay(Color.primary.opacity(0.06))

            SettingsFooterView(viewModel: viewModel)
        }
        .onAppear {
            synchronizeSelection()
            focusSearchFieldIfNeeded()
        }
        .onChange(of: isActive) { _ in
            focusSearchFieldIfNeeded()
        }
        .onChange(of: viewModel.searchResults.map(\.id)) { _ in
            synchronizeSelection()
        }
        .onMoveCommand(perform: moveSelection)
    }

    private var searchHeader: some View {
        HStack(spacing: 10) {
            HStack(spacing: 9) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)

                TextField("Search daily entries", text: $viewModel.searchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .focused($isSearchFieldFocused)
                    .onSubmit(openSelectedResult)
                    .accessibilityLabel("Search daily entries")

                if viewModel.isSearchIndexLoading {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel("Updating search index")
                }

                if !viewModel.searchQuery.isEmpty {
                    Button {
                        viewModel.searchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                    .help("Clear search")
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 36)
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(Color(nsColor: .textBackgroundColor).opacity(0.9))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(
                        isSearchFieldFocused ? Color.accentColor.opacity(0.55) : Color.primary.opacity(0.09),
                        lineWidth: isSearchFieldFocused ? 1.5 : 1
                    )
            )

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(SearchCircleButtonStyle())
            .help("Close search")
            .accessibilityLabel("Close search")
        }
    }

    private var scopeFilters: some View {
        HStack(spacing: 7) {
            ForEach(EntrySearchScope.allCases) { scope in
                Button {
                    viewModel.searchScope = scope
                } label: {
                    Text(scope.displayName)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 10)
                        .frame(height: 26)
                        .foregroundStyle(viewModel.searchScope == scope ? Color.white : Color.secondary)
                        .background(
                            Capsule(style: .continuous)
                                .fill(
                                    viewModel.searchScope == scope
                                        ? Color.accentColor
                                        : Color.primary.opacity(0.055)
                                )
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Search \(scope.displayName)")
                .accessibilityValue(viewModel.searchScope == scope ? "Selected" : "Not selected")
            }

            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var searchContent: some View {
        VStack(spacing: 10) {
            if let errorMessage = viewModel.searchErrorMessage {
                HStack(alignment: .top, spacing: 7) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(errorMessage)
                        .lineLimit(2)
                    Spacer(minLength: 0)
                }
                .font(.caption)
                .foregroundStyle(.red)
                .accessibilityElement(children: .combine)
            }

            if viewModel.isSearchIndexLoading && !viewModel.hasLoadedSearchIndex {
                SearchMessageView(
                    icon: "clock",
                    title: "Preparing your history",
                    message: "Reading your daily entry files. This only happens briefly."
                )
            } else if viewModel.searchResults.isEmpty {
                SearchMessageView(
                    icon: trimmedQuery.isEmpty ? "tray" : "magnifyingglass",
                    title: trimmedQuery.isEmpty ? "No entries to show" : "No matching entries",
                    message: emptyResultsMessage
                )
            } else {
                resultsList
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 440)
    }

    private var resultsList: some View {
        VStack(spacing: 8) {
            HStack {
                Text(resultCountLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("↑↓ to navigate · ↩ to open")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(viewModel.searchResults) { result in
                            Button {
                                selectedResultID = result.id
                                onOpenResult(result)
                            } label: {
                                EntrySearchResultRow(
                                    result: result,
                                    isSelected: selectedResultID == result.id
                                )
                            }
                            .buttonStyle(.plain)
                            .id(result.id)
                            .accessibilityLabel(resultAccessibilityLabel(result))
                            .accessibilityHint("Opens this date in the daily editor")
                            .accessibilityValue(
                                selectedResultID == result.id ? "Selected" : "Not selected"
                            )
                            .accessibilityAddTraits(
                                selectedResultID == result.id ? .isSelected : []
                            )
                            .accessibilityFocused(
                                $accessibilityFocusedResultID,
                                equals: result.id
                            )
                        }
                    }
                    .padding(.vertical, 1)
                    .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onChange(of: selectedResultID) { newValue in
                    guard let newValue else {
                        return
                    }
                    withAnimation(.easeOut(duration: 0.12)) {
                        proxy.scrollTo(newValue, anchor: .center)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var trimmedQuery: String {
        viewModel.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var resultCountLabel: String {
        let count = viewModel.searchResults.count
        return "\(count) \(count == 1 ? "result" : "results")"
    }

    private var emptyResultsMessage: String {
        if !trimmedQuery.isEmpty {
            return "Try fewer words, a different section, or a shorter phrase."
        }

        if viewModel.searchScope == .all {
            return "Your non-empty daily entries will appear here from newest to oldest."
        }
        return "No non-empty \(viewModel.searchScope.displayName.lowercased()) entries were found."
    }

    private func focusSearchFieldIfNeeded() {
        guard isActive else {
            isSearchFieldFocused = false
            return
        }

        DispatchQueue.main.async {
            isSearchFieldFocused = true
        }
    }

    private func synchronizeSelection() {
        let resultIDs = Set(viewModel.searchResults.map(\.id))
        if let selectedResultID, resultIDs.contains(selectedResultID) {
            return
        }
        selectedResultID = viewModel.searchResults.first?.id
    }

    private func moveSelection(_ direction: MoveCommandDirection) {
        guard isActive, !viewModel.searchResults.isEmpty else {
            return
        }

        let results = viewModel.searchResults
        let currentIndex = selectedResultID.flatMap { id in
            results.firstIndex(where: { $0.id == id })
        } ?? 0

        switch direction {
        case .up:
            selectedResultID = results[max(0, currentIndex - 1)].id
        case .down:
            selectedResultID = results[min(results.count - 1, currentIndex + 1)].id
        default:
            return
        }

        if let selectedResultID {
            accessibilityFocusedResultID = selectedResultID
        }
    }

    private func openSelectedResult() {
        let result = selectedResultID.flatMap { id in
            viewModel.searchResults.first(where: { $0.id == id })
        } ?? viewModel.searchResults.first

        if let result {
            onOpenResult(result)
        }
    }

    private func resultAccessibilityLabel(_ result: EntrySearchResult) -> String {
        "\(EntrySearchResultRow.formattedDate(for: result.dateKey)), \(result.field.displayName), \(result.snippet)"
    }
}

struct SearchDetailHeaderView: View {
    let result: EntrySearchResult
    var onBack: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onBack) {
                Label("Results", systemImage: "chevron.left")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 11)
                    .frame(height: 30)
            }
            .buttonStyle(SearchBackButtonStyle())
            .help("Back to search results")
            .accessibilityLabel("Back to search results")

            Spacer(minLength: 4)

            VStack(alignment: .trailing, spacing: 3) {
                Text(EntrySearchResultRow.formattedDate(for: result.dateKey))
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .lineLimit(1)

                HStack(spacing: 5) {
                    Circle()
                        .fill(result.field.accentColor)
                        .frame(width: 6, height: 6)
                    Text(result.field.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct EntrySearchResultRow: View {
    let result: EntrySearchResult
    let isSelected: Bool

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d, yyyy"
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(Self.formattedDate(for: result.dateKey))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)

                Spacer(minLength: 8)

                HStack(spacing: 5) {
                    Circle()
                        .fill(result.field.accentColor)
                        .frame(width: 6, height: 6)
                    Text(result.field.displayName)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(result.field.accentColor)
                }
                .padding(.horizontal, 8)
                .frame(height: 21)
                .background(
                    Capsule(style: .continuous)
                        .fill(result.field.accentColor.opacity(0.1))
                )
            }

            highlightedSnippet
                .font(.system(size: 12.5))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.11) : Color.primary.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(
                    isSelected ? Color.accentColor.opacity(0.4) : Color.primary.opacity(0.06),
                    lineWidth: 1
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    static func formattedDate(for dateKey: String) -> String {
        guard let date = DateKey.date(from: dateKey) else {
            return dateKey
        }
        return dateFormatter.string(from: date)
    }

    private var highlightedSnippet: Text {
        let ranges = highlightRanges(in: result.snippet, terms: result.matchedTerms)
        var output = Text("")
        var cursor = result.snippet.startIndex

        for range in ranges {
            if cursor < range.lowerBound {
                output = output + Text(String(result.snippet[cursor..<range.lowerBound]))
                    .foregroundColor(.secondary)
            }

            output = output + Text(String(result.snippet[range]))
                .fontWeight(.semibold)
                .foregroundColor(result.field.accentColor)
            cursor = range.upperBound
        }

        if cursor < result.snippet.endIndex {
            output = output + Text(String(result.snippet[cursor...]))
                .foregroundColor(.secondary)
        }

        return output
    }

    private func highlightRanges(
        in text: String,
        terms: [String]
    ) -> [Range<String.Index>] {
        var candidates: [Range<String.Index>] = []

        for term in terms where !term.isEmpty {
            var remainingRange = text.startIndex..<text.endIndex
            while let range = text.range(
                of: term,
                options: [.caseInsensitive, .diacriticInsensitive],
                range: remainingRange
            ) {
                candidates.append(range)
                guard range.upperBound < text.endIndex else {
                    break
                }
                remainingRange = range.upperBound..<text.endIndex
            }
        }

        let sorted = candidates.sorted { $0.lowerBound < $1.lowerBound }
        var accepted: [Range<String.Index>] = []

        for range in sorted {
            if let last = accepted.last, range.lowerBound < last.upperBound {
                continue
            }
            accepted.append(range)
        }

        return accepted
    }
}

private struct SearchMessageView: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 25, weight: .light))
                .foregroundStyle(.tertiary)

            Text(title)
                .font(.system(size: 14, weight: .semibold, design: .rounded))

            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 275)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 24)
        .accessibilityElement(children: .combine)
    }
}

private struct SearchCircleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.secondary)
            .background(
                Circle()
                    .fill(configuration.isPressed ? Color.primary.opacity(0.1) : Color.primary.opacity(0.045))
            )
    }
}

private struct SearchBackButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(configuration.isPressed ? Color.primary : Color.secondary)
            .background(
                Capsule(style: .continuous)
                    .fill(configuration.isPressed ? Color.primary.opacity(0.1) : Color.primary.opacity(0.05))
            )
    }
}
