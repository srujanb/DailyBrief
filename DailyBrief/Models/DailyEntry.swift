import Foundation

struct DailyEntry: Codable, Equatable {
    var dateKey: String
    var standup: String
    var achievements: String
    var gratitude: String

    init(dateKey: String, standup: String = "", achievements: String = "", gratitude: String = "") {
        self.dateKey = dateKey
        self.standup = standup
        self.achievements = achievements
        self.gratitude = gratitude
    }

    var isEmpty: Bool {
        trimmed(standup).isEmpty && trimmed(achievements).isEmpty && trimmed(gratitude).isEmpty
    }

    var activity: EntryActivity {
        EntryActivity(
            hasStandup: !trimmed(standup).isEmpty,
            hasAchievements: !trimmed(achievements).isEmpty,
            hasGratitude: !trimmed(gratitude).isEmpty
        )
    }

    private func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct EntryActivity: Codable, Equatable {
    var hasStandup: Bool
    var hasAchievements: Bool
    var hasGratitude: Bool

    static let empty = EntryActivity(hasStandup: false, hasAchievements: false, hasGratitude: false)

    var hasAnyContent: Bool {
        hasStandup || hasAchievements || hasGratitude
    }
}
