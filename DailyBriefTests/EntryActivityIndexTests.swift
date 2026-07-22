import XCTest
@testable import DailyBrief

final class EntryActivityIndexTests: XCTestCase {
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

    func testIndexReportsSingleSectionActivity() throws {
        try store.save(DailyEntry(dateKey: "2026-07-21", achievements: "Fixed a tricky bug"))

        let activity = try EntryActivityIndex(store: store).activity(
            for: DateKey.date(from: "2026-07-21")!
        )

        XCTAssertFalse(activity.hasStandup)
        XCTAssertTrue(activity.hasAchievements)
        XCTAssertFalse(activity.hasGratitude)
    }

    func testIndexReportsMultipleDotsForSameDay() throws {
        try store.save(DailyEntry(
            dateKey: "2026-07-21",
            standup: "Pairing",
            achievements: "Shipped polish",
            gratitude: "Good design review"
        ))

        let activity = try EntryActivityIndex(store: store).load()["2026-07-21"]

        XCTAssertEqual(activity, EntryActivity(hasStandup: true, hasAchievements: true, hasGratitude: true))
    }
}
