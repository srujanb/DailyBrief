import Foundation

@MainActor
final class DailyBriefViewModel: ObservableObject {
    @Published private(set) var selectedDate: Date
    @Published private(set) var activityByDateKey: [String: EntryActivity] = [:]
    @Published private(set) var storageURL: URL
    @Published var lastErrorMessage: String?
    @Published private(set) var searchResults: [EntrySearchResult] = []
    @Published private(set) var isSearchIndexLoading = false
    @Published private(set) var hasLoadedSearchIndex = false
    @Published private(set) var isSearchActive = false
    @Published private(set) var searchErrorMessage: String?

    @Published var searchQuery: String = "" {
        didSet { scheduleSearchIfNeeded() }
    }

    @Published var searchScope: EntrySearchScope = .all {
        didSet { scheduleSearchIfNeeded() }
    }

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
    private var searchRefreshTask: Task<Void, Never>?
    private var searchTask: Task<Void, Never>?
    private var searchIndex = EntrySearchIndex()
    private var searchIndexMutations: [String: DailyEntry] = [:]
    private var searchIndexFingerprint: EntryStore.EntriesFingerprint?
    private var cachedSkippedSearchFileNames: [String] = []
    private var searchIndexGeneration = 0
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
        searchRefreshTask?.cancel()
        searchTask?.cancel()
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

    func beginSearch() {
        isSearchActive = true
        saveImmediately()
        scheduleSearchIfNeeded(immediate: true)
        refreshSearchIndexIfNeeded()
    }

    func endSearch() {
        isSearchActive = false
        searchTask?.cancel()
        searchTask = nil
        searchQuery = ""
        searchScope = .all
        searchResults = []
    }

    @discardableResult
    func openSearchResult(_ result: EntrySearchResult) -> Bool {
        guard
            DateKey.isValid(result.dateKey, calendar: calendar),
            let date = DateKey.date(from: result.dateKey, calendar: calendar)
        else {
            return false
        }
        selectDate(date)
        return true
    }

    func saveImmediately() {
        autosaveTask?.cancel()
        autosaveTask = nil

        do {
            let entry = currentEntry()
            try store.save(entry)
            handlePersistedEntry(entry)
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
            invalidateSearchIndex()
            loadSelectedDate()
            refreshActivityIndex()
            if isSearchActive {
                refreshSearchIndexIfNeeded()
            }
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
            invalidateSearchIndex()
            loadSelectedDate()
            refreshActivityIndex()
            if isSearchActive {
                refreshSearchIndexIfNeeded()
            }
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
                self?.performAutosave()
            } catch {
                // Cancellation is expected while typing quickly.
            }
        }
    }

    private func performAutosave() {
        do {
            let entry = currentEntry()
            try store.save(entry)
            handlePersistedEntry(entry)
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

    private func handlePersistedEntry(_ entry: DailyEntry) {
        if entry.activity.hasAnyContent {
            activityByDateKey[entry.dateKey] = entry.activity
        } else {
            activityByDateKey.removeValue(forKey: entry.dateKey)
        }

        searchIndexMutations[entry.dateKey] = entry

        guard hasLoadedSearchIndex else {
            return
        }

        searchIndex.update(entry)
        scheduleSearchIfNeeded(immediate: true)
    }

    private func refreshSearchIndexIfNeeded() {
        guard !isSearchIndexLoading else {
            return
        }

        searchIndexGeneration += 1

        let generation = searchIndexGeneration
        let baseURL = store.baseURL
        let knownFingerprint = searchIndexFingerprint
        isSearchIndexLoading = true

        searchRefreshTask = Task { [weak self] in
            let worker = Task.detached(priority: .userInitiated) {
                let refreshStore = EntryStore(baseURL: baseURL)

                if let knownFingerprint {
                    let currentFingerprint = try refreshStore.entriesFingerprint()
                    try Task.checkCancellation()

                    if currentFingerprint == knownFingerprint {
                        return SearchIndexRefreshResult(
                            index: nil,
                            fingerprint: currentFingerprint,
                            skippedFileNames: nil
                        )
                    }
                }

                let loadResult = try refreshStore.loadAllEntries()
                try Task.checkCancellation()

                let index = EntrySearchIndex(entries: loadResult.entries)
                try Task.checkCancellation()

                return SearchIndexRefreshResult(
                    index: index,
                    fingerprint: loadResult.fingerprint,
                    skippedFileNames: loadResult.skippedFileURLs.map(\.lastPathComponent)
                )
            }

            do {
                let refreshResult = try await withTaskCancellationHandler(
                    operation: {
                        try await worker.value
                    },
                    onCancel: {
                        worker.cancel()
                    }
                )
                try Task.checkCancellation()

                guard let self, generation == self.searchIndexGeneration else {
                    return
                }

                if var mergedIndex = refreshResult.index {
                    for mutation in self.searchIndexMutations.values {
                        mergedIndex.update(mutation)
                    }

                    self.searchIndex = mergedIndex
                    self.activityByDateKey = mergedIndex.activityByDateKey
                    self.hasLoadedSearchIndex = true
                    self.searchIndexMutations.removeAll(keepingCapacity: true)
                }

                self.searchIndexFingerprint = refreshResult.fingerprint
                self.isSearchIndexLoading = false
                if let skippedFileNames = refreshResult.skippedFileNames {
                    self.cachedSkippedSearchFileNames = skippedFileNames
                    self.searchErrorMessage = self.skippedEntriesMessage(
                        fileNames: skippedFileNames
                    )
                } else {
                    self.searchErrorMessage = self.skippedEntriesMessage(
                        fileNames: self.cachedSkippedSearchFileNames
                    )
                }
                if refreshResult.index != nil {
                    self.scheduleSearchIfNeeded(immediate: true)
                }
            } catch is CancellationError {
                guard let self, generation == self.searchIndexGeneration else {
                    return
                }
                self.isSearchIndexLoading = false
            } catch {
                guard let self, generation == self.searchIndexGeneration else {
                    return
                }
                self.isSearchIndexLoading = false
                self.searchErrorMessage = error.localizedDescription
            }
        }
    }

    private func invalidateSearchIndex() {
        searchRefreshTask?.cancel()
        searchTask?.cancel()
        searchIndexGeneration += 1
        searchIndex = EntrySearchIndex()
        searchIndexMutations.removeAll(keepingCapacity: true)
        searchIndexFingerprint = nil
        cachedSkippedSearchFileNames = []
        searchResults = []
        hasLoadedSearchIndex = false
        isSearchIndexLoading = false
        searchErrorMessage = nil
    }

    private func scheduleSearchIfNeeded(immediate: Bool = false) {
        searchTask?.cancel()
        searchTask = nil

        guard isSearchActive else {
            searchResults = []
            return
        }

        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard hasLoadedSearchIndex else {
            searchResults = []
            return
        }

        let indexSnapshot = searchIndex
        let scope = searchScope
        let resultLimit: Int? = query.isEmpty ? nil : 50

        searchTask = Task { [weak self] in
            do {
                if !immediate {
                    try await Task.sleep(nanoseconds: 120_000_000)
                }
                try Task.checkCancellation()

                let worker = Task.detached(priority: .userInitiated) {
                    indexSnapshot.search(
                        query: query,
                        scope: scope,
                        limit: resultLimit
                    )
                }
                let results = await withTaskCancellationHandler(
                    operation: {
                        await worker.value
                    },
                    onCancel: {
                        worker.cancel()
                    }
                )
                try Task.checkCancellation()

                guard
                    let self,
                    self.isSearchActive,
                    self.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines) == query,
                    self.searchScope == scope
                else {
                    return
                }

                self.searchResults = results
            } catch {
                // Cancellation is expected while the query or filter changes.
            }
        }
    }

    private func skippedEntriesMessage(fileNames: [String]) -> String? {
        guard !fileNames.isEmpty else {
            return nil
        }

        let visibleFileNames = fileNames.prefix(3).joined(separator: ", ")
        let remainingCount = fileNames.count - min(fileNames.count, 3)
        let suffix = remainingCount > 0 ? " and \(remainingCount) more" : ""
        return "Skipped unreadable entry files: \(visibleFileNames)\(suffix)."
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

private struct SearchIndexRefreshResult: Sendable {
    let index: EntrySearchIndex?
    let fingerprint: EntryStore.EntriesFingerprint
    let skippedFileNames: [String]?
}
