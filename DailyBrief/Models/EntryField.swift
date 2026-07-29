enum EntryField: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case standup
    case achievements
    case gratitude

    var id: Self {
        self
    }

    var displayName: String {
        switch self {
        case .standup:
            return "Standup"
        case .achievements:
            return "Achievements"
        case .gratitude:
            return "Gratitude"
        }
    }

    func text(in entry: DailyEntry) -> String {
        switch self {
        case .standup:
            return entry.standup
        case .achievements:
            return entry.achievements
        case .gratitude:
            return entry.gratitude
        }
    }
}
