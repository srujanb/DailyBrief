import Foundation

@MainActor
final class DailyBriefViewModel: ObservableObject {
    @Published private(set) var selectedDate: Date
    @Published private(set) var activityByDateKey: [String: EntryActivity] = [:]
    @Published private(set) var storageURL: URL
    @Published var lastErrorMessage: String?

    @Published var standup: String = "" {
        didSet { scheduleAutosaveIfNeeded() }
    }

    @Published var achievements: String = "" {
        didSet { scheduleAutosaveIfNeeded() }
    }

    @Published var gratitude: String = "" {
        didSet { scheduleAutosaveIfNeeded() }
    }

    private let calendar: Calendar
    private let store: EntryStore
    private let storageSettings: StorageSettings
    private var autosaveTask: Task<Void, Never>?
    private var isLoading = false

    init(
        selectedDate: Date = Date(),
        calendar: Calendar = .current,
        storageSettings: StorageSettings = StorageSettings(),
        store: EntryStore? = nil
    ) {
        self.calendar = calendar
        self.storageSettings = storageSettings
        self.store = store ?? EntryStore(baseURL: storageSettings.storageURL())
        self.storageURL = self.store.baseURL
        self.selectedDate = calendar.startOfDay(for: selectedDate)

        loadSelectedDate()
        refreshActivityIndex()
    }

    deinit {
        autosaveTask?.cancel()
    }

    var selectedDateKey: String {
        DateKey.key(for: selectedDate, calendar: calendar)
    }

    func selectPreviousDay() {
        guard let date = calendar.date(byAdding: .day, value: -1, to: selectedDate) else {
            return
        }
        selectDate(date)
    }

    func selectNextDay() {
        guard let date = calendar.date(byAdding: .day, value: 1, to: selectedDate) else {
            return
        }
        selectDate(date)
    }

    func selectDate(_ date: Date) {
        let normalizedDate = calendar.startOfDay(for: date)
        guard normalizedDate != selectedDate else {
            return
        }

        saveImmediately()
        selectedDate = normalizedDate
        loadSelectedDate()
    }

    func saveImmediately() {
        autosaveTask?.cancel()
        autosaveTask = nil

        do {
            try store.save(currentEntry())
            refreshActivityIndex()
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func useStorageFolder(_ folderURL: URL, copyExistingDataIfDestinationEmpty: Bool = true) {
        saveImmediately()

        do {
            try storageSettings.saveStorageURL(folderURL)
            try store.switchStorage(to: folderURL, copyExistingDataIfDestinationEmpty: copyExistingDataIfDestinationEmpty)
            storageURL = store.baseURL
            loadSelectedDate()
            refreshActivityIndex()
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func resetToDefaultStorageFolder() {
        saveImmediately()

        do {
            storageSettings.clearCustomStorageURL()
            try store.switchStorage(to: storageSettings.defaultStorageURL, copyExistingDataIfDestinationEmpty: true)
            storageURL = store.baseURL
            loadSelectedDate()
            refreshActivityIndex()
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func activity(for date: Date) -> EntryActivity {
        let key = DateKey.key(for: date, calendar: calendar)
        return activityByDateKey[key] ?? .empty
    }

    private func loadSelectedDate() {
        isLoading = true
        defer { isLoading = false }

        do {
            let entry = try store.loadEntry(for: selectedDate, calendar: calendar)
            standup = entry.standup
            achievements = entry.achievements
            gratitude = entry.gratitude
            lastErrorMessage = nil
        } catch {
            standup = ""
            achievements = ""
            gratitude = ""
            lastErrorMessage = error.localizedDescription
        }
    }

    private func scheduleAutosaveIfNeeded() {
        guard !isLoading else {
            return
        }

        autosaveTask?.cancel()
        autosaveTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: 350_000_000)
                await self?.performAutosave()
            } catch {
                // Cancellation is expected while typing quickly.
            }
        }
    }

    private func performAutosave() {
        do {
            try store.save(currentEntry())
            refreshActivityIndex()
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    private func refreshActivityIndex() {
        do {
            activityByDateKey = try EntryActivityIndex(store: store).load()
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    private func currentEntry() -> DailyEntry {
        DailyEntry(
            dateKey: selectedDateKey,
            standup: standup,
            achievements: achievements,
            gratitude: gratitude
        )
    }
}
