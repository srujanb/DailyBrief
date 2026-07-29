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

    func testLoadsAllEntriesInDateOrder() throws {
        try store.save(DailyEntry(dateKey: "2026-07-22", gratitude: "A useful review"))
        try store.save(DailyEntry(dateKey: "2026-07-20", achievements: "Shipped search"))

        XCTAssertEqual(
            try store.loadAllEntries().entries.map(\.dateKey),
            ["2026-07-20", "2026-07-22"]
        )
    }

    func testBulkLoadSkipsMalformedFilesAndKeepsValidEntries() throws {
        try store.save(DailyEntry(dateKey: "2026-07-21", achievements: "Valid entry"))
        let malformedFileURL = store.entriesDirectory.appendingPathComponent("2026-07-22.json")
        try Data("not valid JSON".utf8).write(to: malformedFileURL)

        let result = try store.loadAllEntries()

        XCTAssertEqual(result.entries.map(\.dateKey), ["2026-07-21"])
        XCTAssertEqual(
            result.skippedFileURLs.map(\.lastPathComponent),
            [malformedFileURL.lastPathComponent]
        )
    }

    func testFilenameIsAuthoritativeWhenPayloadDateKeyDiffers() throws {
        try FileManager.default.createDirectory(
            at: store.entriesDirectory,
            withIntermediateDirectories: true
        )
        let fileURL = store.entriesDirectory.appendingPathComponent("2026-07-21.json")
        let mismatchedEntry = DailyEntry(
            dateKey: "1999-01-01",
            achievements: "Copied entry"
        )
        try JSONEncoder().encode(mismatchedEntry).write(to: fileURL)

        let entry = try store.loadEntry(forKey: "2026-07-21")

        XCTAssertEqual(entry.dateKey, "2026-07-21")
        XCTAssertEqual(entry.achievements, "Copied entry")
    }

    func testBulkLoadSkipsValidJSONWithNonDateFilename() throws {
        try FileManager.default.createDirectory(
            at: store.entriesDirectory,
            withIntermediateDirectories: true
        )
        let fileURL = store.entriesDirectory.appendingPathComponent("backup.json")
        try JSONEncoder().encode(DailyEntry(
            dateKey: "2026-07-21",
            achievements: "Backup"
        )).write(to: fileURL)

        let result = try store.loadAllEntries()

        XCTAssertTrue(result.entries.isEmpty)
        XCTAssertEqual(result.skippedFileURLs.map(\.lastPathComponent), ["backup.json"])
    }

    func testEntriesFingerprintChangesWhenFilesChange() throws {
        try store.save(DailyEntry(dateKey: "2026-07-21", achievements: "First"))
        let originalFingerprint = try store.entriesFingerprint()

        XCTAssertEqual(try store.entriesFingerprint(), originalFingerprint)

        try store.save(DailyEntry(
            dateKey: "2026-07-21",
            achievements: "A substantially longer updated achievement"
        ))

        XCTAssertNotEqual(try store.entriesFingerprint(), originalFingerprint)
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

    func testStatusItemDateResetGateOnlyResetsAfterMoreThanOneHour() {
        var gate = StatusItemDateResetGate()
        let firstOpenDate = Date(timeIntervalSinceReferenceDate: 1_000)

        XCTAssertTrue(gate.shouldResetDate(forStatusItemOpenAt: firstOpenDate))
        XCTAssertFalse(gate.shouldResetDate(forStatusItemOpenAt: firstOpenDate.addingTimeInterval(60 * 60)))
        XCTAssertTrue(gate.shouldResetDate(forStatusItemOpenAt: firstOpenDate.addingTimeInterval(2 * 60 * 60 + 1)))
    }
}
