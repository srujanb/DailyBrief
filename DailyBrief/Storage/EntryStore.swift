import Foundation

final class EntryStore {
    struct EntryFileFingerprint: Equatable, Sendable {
        let fileName: String
        let fileSize: Int
        let modificationTime: TimeInterval
    }

    struct EntriesFingerprint: Equatable, Sendable {
        let files: [EntryFileFingerprint]

        static let empty = EntriesFingerprint(files: [])
    }

    struct LoadAllEntriesResult: Sendable {
        let entries: [DailyEntry]
        let skippedFileURLs: [URL]
        let fingerprint: EntriesFingerprint
    }

    enum StoreError: LocalizedError {
        case invalidEntryFile(URL)
        case entriesChangedDuringLoad(URL)

        var errorDescription: String? {
            switch self {
            case .invalidEntryFile(let url):
                return "Could not read DailyBrief entry at \(url.path)."
            case .entriesChangedDuringLoad(let url):
                return "DailyBrief entries changed while reading \(url.path). Please try again."
            }
        }
    }

    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    private(set) var baseURL: URL

    init(baseURL: URL = StorageSettings().storageURL(), fileManager: FileManager = .default) {
        self.baseURL = baseURL
        self.fileManager = fileManager

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder
        self.decoder = JSONDecoder()
    }

    var entriesDirectory: URL {
        baseURL.appendingPathComponent("entries", isDirectory: true)
    }

    func loadEntry(for date: Date, calendar: Calendar = .current) throws -> DailyEntry {
        try loadEntry(forKey: DateKey.key(for: date, calendar: calendar))
    }

    func loadEntry(forKey dateKey: String) throws -> DailyEntry {
        let fileURL = entryFileURL(forKey: dateKey)
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return DailyEntry(dateKey: dateKey)
        }

        do {
            let data = try Data(contentsOf: fileURL)
            var entry = try decoder.decode(DailyEntry.self, from: data)
            entry.dateKey = dateKey
            return entry
        } catch {
            throw StoreError.invalidEntryFile(fileURL)
        }
    }

    func save(_ entry: DailyEntry) throws {
        try ensureEntriesDirectoryExists()

        let fileURL = entryFileURL(forKey: entry.dateKey)
        let data = try encoder.encode(entry)

        if entry.isEmpty {
            if fileManager.fileExists(atPath: fileURL.path) {
                try fileManager.removeItem(at: fileURL)
            }
            return
        }

        try data.write(to: fileURL, options: [.atomic])
    }

    func loadActivityIndex() throws -> [String: EntryActivity] {
        guard fileManager.fileExists(atPath: entriesDirectory.path) else {
            return [:]
        }

        let fileURLs = try fileManager.contentsOfDirectory(
            at: entriesDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )

        var index: [String: EntryActivity] = [:]
        for fileURL in fileURLs where fileURL.pathExtension == "json" {
            let key = fileURL.deletingPathExtension().lastPathComponent
            let entry = try loadEntry(forKey: key)
            if entry.activity.hasAnyContent {
                index[key] = entry.activity
            }
        }

        return index
    }

    func loadAllEntries() throws -> LoadAllEntriesResult {
        for _ in 0..<3 {
            try Task.checkCancellation()
            let fingerprintBeforeLoad = try entriesFingerprint()
            let fileURLs = fingerprintBeforeLoad.files.map {
                entriesDirectory.appendingPathComponent($0.fileName)
            }
            let loadedEntries = try loadEntries(from: fileURLs)
            let fingerprintAfterLoad = try entriesFingerprint()

            if fingerprintBeforeLoad == fingerprintAfterLoad {
                return LoadAllEntriesResult(
                    entries: loadedEntries.entries,
                    skippedFileURLs: loadedEntries.skippedFileURLs,
                    fingerprint: fingerprintAfterLoad
                )
            }
        }

        throw StoreError.entriesChangedDuringLoad(entriesDirectory)
    }

    private func loadEntries(from fileURLs: [URL]) throws -> (
        entries: [DailyEntry],
        skippedFileURLs: [URL]
    ) {
        var entries: [DailyEntry] = []
        var skippedFileURLs: [URL] = []

        for fileURL in fileURLs {
            try Task.checkCancellation()
            let dateKey = fileURL.deletingPathExtension().lastPathComponent

            guard DateKey.isValid(dateKey) else {
                skippedFileURLs.append(fileURL)
                continue
            }

            do {
                entries.append(try loadEntry(forKey: dateKey))
            } catch {
                skippedFileURLs.append(fileURL)
            }
        }

        return (entries, skippedFileURLs)
    }

    func entriesFingerprint() throws -> EntriesFingerprint {
        guard fileManager.fileExists(atPath: entriesDirectory.path) else {
            return .empty
        }

        let fileURLs = try fileManager.contentsOfDirectory(
            at: entriesDirectory,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )
        let sortedFileURLs = fileURLs
            .filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        return try makeFingerprint(for: sortedFileURLs)
    }

    func switchStorage(to newBaseURL: URL, copyExistingDataIfDestinationEmpty: Bool) throws {
        let oldEntriesDirectory = entriesDirectory
        let newEntriesDirectory = newBaseURL.appendingPathComponent("entries", isDirectory: true)
        let destinationHasEntries: Bool
        if fileManager.fileExists(atPath: newEntriesDirectory.path) {
            destinationHasEntries = !(try fileManager.contentsOfDirectory(atPath: newEntriesDirectory.path).isEmpty)
        } else {
            destinationHasEntries = false
        }

        if copyExistingDataIfDestinationEmpty && !destinationHasEntries && fileManager.fileExists(atPath: oldEntriesDirectory.path) {
            try fileManager.createDirectory(at: newEntriesDirectory, withIntermediateDirectories: true)
            let oldEntryFiles = try fileManager.contentsOfDirectory(
                at: oldEntriesDirectory,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )

            for oldFileURL in oldEntryFiles where oldFileURL.pathExtension == "json" {
                let destinationURL = newEntriesDirectory.appendingPathComponent(oldFileURL.lastPathComponent)
                if !fileManager.fileExists(atPath: destinationURL.path) {
                    try fileManager.copyItem(at: oldFileURL, to: destinationURL)
                }
            }
        } else {
            try fileManager.createDirectory(at: newEntriesDirectory, withIntermediateDirectories: true)
        }

        baseURL = newBaseURL
    }

    private func ensureEntriesDirectoryExists() throws {
        try fileManager.createDirectory(at: entriesDirectory, withIntermediateDirectories: true)
    }

    private func makeFingerprint(for fileURLs: [URL]) throws -> EntriesFingerprint {
        let files = try fileURLs.map { fileURL in
            try Task.checkCancellation()
            let values = try fileURL.resourceValues(
                forKeys: [.fileSizeKey, .contentModificationDateKey]
            )
            return EntryFileFingerprint(
                fileName: fileURL.lastPathComponent,
                fileSize: values.fileSize ?? 0,
                modificationTime: values.contentModificationDate?.timeIntervalSinceReferenceDate ?? 0
            )
        }
        return EntriesFingerprint(files: files)
    }

    private func entryFileURL(forKey dateKey: String) -> URL {
        entriesDirectory.appendingPathComponent(dateKey).appendingPathExtension("json")
    }
}
