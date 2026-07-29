import XCTest
@testable import DailyBrief

final class EntrySearchIndexTests: XCTestCase {
    func testMatchesSingularPluralAndSeparatedTerms() {
        let index = EntrySearchIndex(entries: [
            DailyEntry(dateKey: "2026-07-20", achievements: "The test failed during CI."),
            DailyEntry(
                dateKey: "2026-07-21",
                achievements: "The multiple tests in the codebase failed after the migration."
            ),
            DailyEntry(dateKey: "2026-07-22", achievements: "The test passed.")
        ])

        let results = index.search(query: "the tests failed")

        XCTAssertEqual(Set(results.map(\.dateKey)), ["2026-07-20", "2026-07-21"])
    }

    func testMatchesInflectionsAndTermsInAnyOrder() {
        let index = EntrySearchIndex(entries: [
            DailyEntry(
                dateKey: "2026-07-21",
                standup: "Deployed the service after testing the migration."
            )
        ])

        let results = index.search(query: "tests deploy")

        XCTAssertEqual(results.map(\.dateKey), ["2026-07-21"])
        XCTAssertEqual(results.first?.field, .standup)
    }

    func testAllowsOneConservativeTypoInMultiTermQuery() {
        let index = EntrySearchIndex(entries: [
            DailyEntry(dateKey: "2026-07-21", achievements: "The tests failed in CI.")
        ])

        XCTAssertEqual(index.search(query: "tsets failed").count, 1)
    }

    func testRejectsMultiTermResultWhenEveryTermOnlyFuzzilyMatches() {
        let index = EntrySearchIndex(entries: [
            DailyEntry(dateKey: "2026-07-21", achievements: "The best boat sailed today.")
        ])

        XCTAssertTrue(index.search(query: "test failed").isEmpty)
    }

    func testRequiresDistinctSectionTokensForDistinctQueryTerms() {
        let singleTokenIndex = EntrySearchIndex(entries: [
            DailyEntry(dateKey: "2026-07-21", achievements: "Plan")
        ])
        let completeIndex = EntrySearchIndex(entries: [
            DailyEntry(dateKey: "2026-07-21", achievements: "Plan the plant migration")
        ])

        XCTAssertTrue(singleTokenIndex.search(query: "plan plant").isEmpty)
        XCTAssertEqual(completeIndex.search(query: "plan plant").count, 1)
    }

    func testDistinctTokenAssignmentIsIndependentOfQueryOrder() {
        let index = EntrySearchIndex(entries: [
            DailyEntry(dateKey: "2026-07-21", achievements: "Testing test")
        ])

        XCTAssertEqual(index.search(query: "testing testign").count, 1)
        XCTAssertEqual(index.search(query: "testign testing").count, 1)
    }

    func testNormalizesShortAcronymPlurals() {
        let index = EntrySearchIndex(entries: [
            DailyEntry(dateKey: "2026-07-21", standup: "Reviewed PRs and IDs")
        ])

        XCTAssertEqual(index.search(query: "PR").count, 1)
        XCTAssertEqual(index.search(query: "ID").count, 1)
    }

    func testSymbolOnlyQueryDoesNotBrowseUnrelatedEntries() {
        let index = EntrySearchIndex(entries: [
            DailyEntry(dateKey: "2026-07-21", achievements: "Shipped search")
        ])

        XCTAssertTrue(index.search(query: "!!!", limit: nil).isEmpty)
        XCTAssertEqual(index.search(query: "", limit: nil).count, 1)
    }

    func testDoesNotConflateShortWordsWithPastTenseLemmas() {
        let index = EntrySearchIndex(entries: [
            DailyEntry(dateKey: "2026-07-21", achievements: "Hated the rated option")
        ])

        XCTAssertTrue(index.search(query: "hat").isEmpty)
        XCTAssertTrue(index.search(query: "rat").isEmpty)
    }

    func testRanksExactPhraseBeforeSeparatedAndNormalizedMatches() {
        let index = EntrySearchIndex(entries: [
            DailyEntry(dateKey: "2026-07-23", achievements: "A test failed."),
            DailyEntry(dateKey: "2026-07-22", achievements: "The tests eventually failed."),
            DailyEntry(dateKey: "2026-07-21", achievements: "The tests failed.")
        ])

        let results = index.search(query: "tests failed")

        XCTAssertEqual(
            results.map(\.dateKey),
            ["2026-07-21", "2026-07-22", "2026-07-23"]
        )
    }

    func testExactPhraseSnippetUsesTheMatchingOccurrenceAfterRepeatedTerms() {
        let repeatedTerms = Array(repeating: "tests passed", count: 20)
            .joined(separator: " ")
        let index = EntrySearchIndex(entries: [
            DailyEntry(
                dateKey: "2026-07-21",
                achievements: repeatedTerms + " before the tests failed"
            )
        ])

        let result = index.search(query: "tests failed").first

        XCTAssertTrue(
            result?.snippet.contains("tests failed") == true,
            "Unexpected snippet: \(result?.snippet ?? "nil")"
        )
    }

    func testUsesNewestDateToBreakEqualScores() {
        let index = EntrySearchIndex(entries: [
            DailyEntry(dateKey: "2026-07-20", achievements: "Shipped search"),
            DailyEntry(dateKey: "2026-07-22", achievements: "Shipped search")
        ])

        XCTAssertEqual(
            index.search(query: "shipped search").map(\.dateKey),
            ["2026-07-22", "2026-07-20"]
        )
    }

    func testFiltersBySection() {
        let index = EntrySearchIndex(entries: [
            DailyEntry(
                dateKey: "2026-07-21",
                standup: "Reviewed the search implementation",
                achievements: "Shipped the search implementation",
                gratitude: "Helpful search feedback"
            )
        ])

        let results = index.search(query: "search", scope: .achievements)

        XCTAssertEqual(results.map(\.field), [.achievements])
    }

    func testEmptyQueryBrowsesFilteredEntriesNewestFirst() {
        let index = EntrySearchIndex(entries: [
            DailyEntry(dateKey: "2026-07-20", achievements: "Older achievement"),
            DailyEntry(dateKey: "2026-07-21", standup: "Standup only"),
            DailyEntry(dateKey: "2026-07-22", achievements: "Newer achievement")
        ])

        let results = index.search(
            query: "",
            scope: .achievements,
            limit: nil
        )

        XCTAssertEqual(results.map(\.dateKey), ["2026-07-22", "2026-07-20"])
        XCTAssertEqual(results.map(\.field), [.achievements, .achievements])
    }

    func testEmptyQueryCanReturnMoreThanSearchResultCap() {
        let entries = (0..<75).map { offset in
            DailyEntry(
                dateKey: String(format: "2026-%03d", offset),
                achievements: "Achievement \(offset)"
            )
        }
        let index = EntrySearchIndex(entries: entries)

        XCTAssertEqual(
            index.search(query: "", scope: .achievements, limit: nil).count,
            75
        )
    }

    func testRequiresAllTermsWithinTheSameSection() {
        let index = EntrySearchIndex(entries: [
            DailyEntry(
                dateKey: "2026-07-21",
                standup: "The tests ran.",
                achievements: "The deployment failed."
            )
        ])

        XCTAssertTrue(index.search(query: "tests failed").isEmpty)
    }

    func testSearchIsCaseAndDiacriticInsensitive() {
        let index = EntrySearchIndex(entries: [
            DailyEntry(dateKey: "2026-07-21", gratitude: "A CAFÉ conversation helped.")
        ])

        XCTAssertEqual(index.search(query: "cafe").first?.field, .gratitude)
    }

    func testBuildsContextSnippetAroundTheMatch() {
        let prefix = String(repeating: "Earlier context ", count: 20)
        let suffix = String(repeating: " later context", count: 20)
        let index = EntrySearchIndex(entries: [
            DailyEntry(
                dateKey: "2026-07-21",
                achievements: prefix + "migration completed successfully" + suffix
            )
        ])

        let result = index.search(query: "migration").first

        XCTAssertNotNil(result)
        XCTAssertTrue(result?.snippet.contains("migration") == true)
        XCTAssertTrue(result?.snippet.hasPrefix("…") == true)
        XCTAssertTrue(result?.snippet.hasSuffix("…") == true)
        XCTAssertLessThanOrEqual(result?.snippet.count ?? .max, 172)
    }

    func testHonorsResultLimit() {
        let entries = (1...20).map {
            DailyEntry(dateKey: String(format: "2026-07-%02d", $0), standup: "Search work")
        }
        let index = EntrySearchIndex(entries: entries)

        XCTAssertEqual(index.search(query: "search", limit: 5).count, 5)
    }

    func testIncrementalUpdateAndDeletion() {
        var index = EntrySearchIndex()
        let entry = DailyEntry(dateKey: "2026-07-21", achievements: "Shipped local search")

        index.update(entry)
        XCTAssertEqual(index.search(query: "local search").count, 1)
        XCTAssertEqual(index.activityByDateKey[entry.dateKey]?.hasAchievements, true)

        index.update(DailyEntry(dateKey: entry.dateKey))
        XCTAssertTrue(index.search(query: "local search").isEmpty)
        XCTAssertNil(index.activityByDateKey[entry.dateKey])
    }

    func testSearchesSyntheticFiveYearCorpus() {
        let calendar = Calendar(identifier: .gregorian)
        let startDate = DateKey.date(from: "2021-01-01", calendar: calendar)!
        let targetOffset = 1_437
        let entries = (0..<1_826).map { offset -> DailyEntry in
            let date = calendar.date(byAdding: .day, value: offset, to: startDate)!
            let text = offset == targetOffset
                ? "Completed the authentication migration"
                : "Reviewed pull requests and planned upcoming work"
            return DailyEntry(
                dateKey: DateKey.key(for: date, calendar: calendar),
                achievements: text
            )
        }
        let index = EntrySearchIndex(entries: entries)

        let results = index.search(query: "authentication migrations")

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.sourceText, "Completed the authentication migration")
    }
}
