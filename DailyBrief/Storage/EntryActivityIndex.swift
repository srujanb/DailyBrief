import Foundation

struct EntryActivityIndex {
    private let store: EntryStore

    init(store: EntryStore) {
        self.store = store
    }

    func load() throws -> [String: EntryActivity] {
        try store.loadActivityIndex()
    }

    func activity(for date: Date, calendar: Calendar = .current) throws -> EntryActivity {
        let key = DateKey.key(for: date, calendar: calendar)
        return try load()[key] ?? .empty
    }
}
