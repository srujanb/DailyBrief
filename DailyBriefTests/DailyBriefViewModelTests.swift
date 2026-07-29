import XCTest
@testable import DailyBrief

@MainActor
final class DailyBriefViewModelTests: XCTestCase {
    private var temporaryDirectory: URL!
    private var store: EntryStore!

    override func setUpWithError() throws {
        try super.setUpWithError()
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        store = EntryStore(baseURL: temporaryDirectory)
    }

    override func tearDownWithError() throws {
        if let temporaryDirectory {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
        temporaryDirectory = nil
        store = nil
        try super.tearDownWithError()
    }

    func testSavesCurrentDateBeforeSwitchingDates() throws {
        let startDate = DateKey.date(from: "2026-07-21")!
        let viewModel = DailyBriefViewModel(selectedDate: startDate, store: store)

        viewModel.standup = "Finished the storage layer"
        viewModel.selectNextDay()

        XCTAssertEqual(try store.loadEntry(forKey: "2026-07-21").standup, "Finished the storage layer")
        XCTAssertEqual(viewModel.selectedDateKey, "2026-07-22")
        XCTAssertEqual(viewModel.standup, "")
    }

    func testAutosavesAfterEditing() async throws {
        let startDate = DateKey.date(from: "2026-07-21")!
        let viewModel = DailyBriefViewModel(selectedDate: startDate, store: store)

        viewModel.achievements = "Created the activity calendar"
        try await Task.sleep(nanoseconds: 500_000_000)

        XCTAssertEqual(try store.loadEntry(forKey: "2026-07-21").achievements, "Created the activity calendar")
    }

    func testSwitchingStorageFolderCopiesExistingEntries() throws {
        let startDate = DateKey.date(from: "2026-07-21")!
        let suiteName = "DailyBriefTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let storageSettings = StorageSettings(defaults: defaults)
        let viewModel = DailyBriefViewModel(selectedDate: startDate, storageSettings: storageSettings, store: store)
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: destination)
        }

        viewModel.gratitude = "A quiet morning"
        viewModel.saveImmediately()
        viewModel.useStorageFolder(destination)

        XCTAssertEqual(viewModel.storageURL, destination)
        XCTAssertEqual(try store.loadEntry(forKey: "2026-07-21").gratitude, "A quiet morning")
    }

    func testSearchIncludesCurrentUnsavedText() async throws {
        let startDate = DateKey.date(from: "2026-07-21")!
        let viewModel = DailyBriefViewModel(selectedDate: startDate, store: store)
        viewModel.achievements = "The integration test failed after deployment"

        viewModel.beginSearch()
        viewModel.searchQuery = "tests failed"

        let foundResult = await waitUntil {
            viewModel.searchResults.contains {
                $0.dateKey == "2026-07-21" && $0.field == .achievements
            }
        }

        XCTAssertTrue(foundResult)
        XCTAssertEqual(
            try store.loadEntry(forKey: "2026-07-21").achievements,
            "The integration test failed after deployment"
        )
    }

    func testOpeningSearchResultPreservesSearchSession() async throws {
        try store.save(DailyEntry(
            dateKey: "2026-07-20",
            achievements: "Shipped the local search experience"
        ))
        let startDate = DateKey.date(from: "2026-07-21")!
        let viewModel = DailyBriefViewModel(selectedDate: startDate, store: store)

        viewModel.beginSearch()
        viewModel.searchScope = .achievements
        viewModel.searchQuery = "local search"

        let foundResult = await waitUntil {
            viewModel.searchResults.first?.dateKey == "2026-07-20"
        }
        guard foundResult, let result = viewModel.searchResults.first else {
            XCTFail("Expected a search result")
            return
        }
        let resultIDs = viewModel.searchResults.map(\.id)

        viewModel.openSearchResult(result)

        XCTAssertEqual(viewModel.selectedDateKey, "2026-07-20")
        XCTAssertEqual(viewModel.searchQuery, "local search")
        XCTAssertEqual(viewModel.searchScope, .achievements)
        XCTAssertEqual(viewModel.searchResults.map(\.id), resultIDs)
        XCTAssertTrue(viewModel.isSearchActive)
    }

    func testInvalidSearchResultDoesNotChangeSelectedDate() {
        let viewModel = DailyBriefViewModel(
            selectedDate: DateKey.date(from: "2026-07-21")!,
            store: store
        )
        let invalidResult = EntrySearchResult(
            dateKey: "backup",
            field: .achievements,
            sourceText: "Backup",
            snippet: "Backup",
            matchedTerms: [],
            score: 0
        )

        XCTAssertFalse(viewModel.openSearchResult(invalidResult))
        XCTAssertEqual(viewModel.selectedDateKey, "2026-07-21")
    }

    func testLatestQueryWinsWhenSearchChangesQuickly() async throws {
        try store.save(DailyEntry(dateKey: "2026-07-20", standup: "Investigated an apple issue"))
        try store.save(DailyEntry(dateKey: "2026-07-21", standup: "Investigated a banana issue"))
        let viewModel = DailyBriefViewModel(
            selectedDate: DateKey.date(from: "2026-07-22")!,
            store: store
        )

        viewModel.beginSearch()
        let loaded = await waitUntil { viewModel.hasLoadedSearchIndex }
        XCTAssertTrue(loaded)

        viewModel.searchQuery = "apple"
        viewModel.searchQuery = "banana"

        let foundLatestResult = await waitUntil {
            viewModel.searchResults.count == 1
                && viewModel.searchResults.first?.dateKey == "2026-07-21"
        }

        XCTAssertTrue(foundLatestResult)
        XCTAssertEqual(viewModel.searchQuery, "banana")
    }

    func testEmptyQueryShowsFilteredEntriesNewestFirst() async throws {
        try store.save(DailyEntry(dateKey: "2026-07-19", achievements: "Older achievement"))
        try store.save(DailyEntry(dateKey: "2026-07-20", standup: "Standup only"))
        try store.save(DailyEntry(dateKey: "2026-07-21", achievements: "Newer achievement"))
        let viewModel = DailyBriefViewModel(
            selectedDate: DateKey.date(from: "2026-07-22")!,
            store: store
        )

        viewModel.beginSearch()
        viewModel.searchScope = .achievements

        let loadedResults = await waitUntil {
            viewModel.searchResults.count == 2
        }

        XCTAssertTrue(loadedResults)
        XCTAssertEqual(viewModel.searchQuery, "")
        XCTAssertEqual(
            viewModel.searchResults.map(\.dateKey),
            ["2026-07-21", "2026-07-19"]
        )
        XCTAssertEqual(
            viewModel.searchResults.map(\.field),
            [.achievements, .achievements]
        )
    }

    func testActiveSearchReloadsAfterStorageSwitch() async throws {
        let suiteName = "DailyBriefTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: destination)
        }
        let destinationStore = EntryStore(baseURL: destination)
        try destinationStore.save(DailyEntry(
            dateKey: "2026-07-19",
            gratitude: "The migration review was helpful"
        ))

        let viewModel = DailyBriefViewModel(
            selectedDate: DateKey.date(from: "2026-07-21")!,
            storageSettings: StorageSettings(defaults: defaults),
            store: store
        )
        viewModel.beginSearch()
        viewModel.searchQuery = "migration review"

        viewModel.useStorageFolder(destination, copyExistingDataIfDestinationEmpty: false)

        let refreshed = await waitUntil {
            viewModel.searchResults.first?.dateKey == "2026-07-19"
        }

        XCTAssertTrue(refreshed)
        XCTAssertEqual(viewModel.storageURL, destination)
    }

    func testSearchKeepsValidResultsAndWarnsAboutMalformedFiles() async throws {
        try store.save(DailyEntry(
            dateKey: "2026-07-20",
            achievements: "Valid searchable entry"
        ))
        let malformedFileURL = store.entriesDirectory.appendingPathComponent("2026-07-19.json")
        try Data("invalid".utf8).write(to: malformedFileURL)
        let viewModel = DailyBriefViewModel(
            selectedDate: DateKey.date(from: "2026-07-21")!,
            store: store
        )

        viewModel.beginSearch()
        viewModel.searchQuery = "searchable"

        let loaded = await waitUntil {
            viewModel.searchResults.first?.dateKey == "2026-07-20"
                && viewModel.searchErrorMessage != nil
        }

        XCTAssertTrue(loaded)
        XCTAssertTrue(viewModel.searchErrorMessage?.contains("2026-07-19.json") == true)

        viewModel.endSearch()
        viewModel.beginSearch()

        let restoredWarning = await waitUntil {
            !viewModel.isSearchIndexLoading
                && viewModel.searchErrorMessage?.contains("2026-07-19.json") == true
        }
        XCTAssertTrue(restoredWarning)
    }

    func testReopeningSearchRefreshesExternallyChangedFiles() async throws {
        try store.save(DailyEntry(
            dateKey: "2026-07-20",
            achievements: "Initial entry"
        ))
        let viewModel = DailyBriefViewModel(
            selectedDate: DateKey.date(from: "2026-07-21")!,
            store: store
        )
        viewModel.beginSearch()
        let initiallyLoaded = await waitUntil { viewModel.hasLoadedSearchIndex }
        XCTAssertTrue(initiallyLoaded)
        viewModel.endSearch()

        try store.save(DailyEntry(
            dateKey: "2026-07-19",
            achievements: "Externally synced milestone"
        ))

        viewModel.beginSearch()
        viewModel.searchQuery = "synced milestone"

        let refreshed = await waitUntil {
            viewModel.searchResults.first?.dateKey == "2026-07-19"
        }

        XCTAssertTrue(refreshed)
    }

    func testCompletedRefreshDoesNotReapplyStaleLocalMutation() async throws {
        try store.save(DailyEntry(
            dateKey: "2026-07-20",
            achievements: "Initial value"
        ))
        let viewModel = DailyBriefViewModel(
            selectedDate: DateKey.date(from: "2026-07-20")!,
            store: store
        )
        viewModel.beginSearch()
        let initiallyLoaded = await waitUntil { viewModel.hasLoadedSearchIndex }
        XCTAssertTrue(initiallyLoaded)

        viewModel.endSearch()
        viewModel.achievements = "Locally edited value"
        viewModel.saveImmediately()
        viewModel.selectNextDay()
        viewModel.beginSearch()
        let localRefreshCompleted = await waitUntil { !viewModel.isSearchIndexLoading }
        XCTAssertTrue(localRefreshCompleted)

        viewModel.endSearch()
        try store.save(DailyEntry(
            dateKey: "2026-07-20",
            achievements: "Externally replaced value"
        ))
        viewModel.beginSearch()
        viewModel.searchQuery = "externally replaced"

        let externalValueLoaded = await waitUntil {
            viewModel.searchResults.first?.sourceText == "Externally replaced value"
        }
        XCTAssertTrue(externalValueLoaded)
    }

    func testEndingSearchClearsTransientSearchState() async {
        let viewModel = DailyBriefViewModel(
            selectedDate: DateKey.date(from: "2026-07-21")!,
            store: store
        )
        viewModel.beginSearch()
        viewModel.searchQuery = "anything"

        viewModel.endSearch()

        XCTAssertFalse(viewModel.isSearchActive)
        XCTAssertEqual(viewModel.searchQuery, "")
        XCTAssertEqual(viewModel.searchScope, .all)
        XCTAssertTrue(viewModel.searchResults.isEmpty)
    }

    private func waitUntil(
        timeout: TimeInterval = 3,
        condition: @escaping () -> Bool
    ) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            if condition() {
                return true
            }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }

        return condition()
    }
}
