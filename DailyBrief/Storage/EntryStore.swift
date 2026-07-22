import Foundation

final class EntryStore {
    enum StoreError: LocalizedError {
        case invalidEntryFile(URL)

        var errorDescription: String? {
            switch self {
            case .invalidEntryFile(let url):
                return "Could not read DailyBrief entry at \(url.path)."
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
            return try decoder.decode(DailyEntry.self, from: data)
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

    private func entryFileURL(forKey dateKey: String) -> URL {
        entriesDirectory.appendingPathComponent(dateKey).appendingPathExtension("json")
    }
}
