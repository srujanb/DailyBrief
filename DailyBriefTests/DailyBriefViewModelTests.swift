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
}
