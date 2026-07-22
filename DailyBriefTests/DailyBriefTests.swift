import XCTest
@testable import DailyBrief

final class EntryStoreTests: XCTestCase {
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

    func testSaveAndLoadEntry() throws {
        let entry = DailyEntry(
            dateKey: "2026-07-21",
            standup: "Built the menu bar app",
            achievements: "Got autosave working",
            gratitude: "Helpful feedback"
        )

        try store.save(entry)

        XCTAssertEqual(try store.loadEntry(forKey: "2026-07-21"), entry)
    }

    func testEmptyDayReturnsBlankEntry() throws {
        let entry = try store.loadEntry(forKey: "2026-07-22")

        XCTAssertEqual(entry, DailyEntry(dateKey: "2026-07-22"))
    }

    func testOverwriteEntry() throws {
        try store.save(DailyEntry(dateKey: "2026-07-21", standup: "Draft"))
        try store.save(DailyEntry(dateKey: "2026-07-21", standup: "Final"))

        XCTAssertEqual(try store.loadEntry(forKey: "2026-07-21").standup, "Final")
    }

    func testSavingEmptyEntryRemovesFile() throws {
        try store.save(DailyEntry(dateKey: "2026-07-21", gratitude: "Coffee"))
        try store.save(DailyEntry(dateKey: "2026-07-21"))

        XCTAssertEqual(try store.loadActivityIndex(), [:])
        XCTAssertEqual(try store.loadEntry(forKey: "2026-07-21"), DailyEntry(dateKey: "2026-07-21"))
    }

    func testSwitchStorageCopiesExistingEntriesToEmptyDestination() throws {
        try store.save(DailyEntry(dateKey: "2026-07-21", achievements: "Shipped v1"))

        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: destination)
        }

        try store.switchStorage(to: destination, copyExistingDataIfDestinationEmpty: true)

        XCTAssertEqual(try store.loadEntry(forKey: "2026-07-21").achievements, "Shipped v1")
    }
}
