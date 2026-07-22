import Foundation

struct StorageSettings {
    private enum Keys {
        static let storageBookmark = "storageBookmark"
    }

    private let defaults: UserDefaults
    private let fileManager: FileManager

    init(defaults: UserDefaults = .standard, fileManager: FileManager = .default) {
        self.defaults = defaults
        self.fileManager = fileManager
    }

    var defaultStorageURL: URL {
        let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support", isDirectory: true)
        return baseURL.appendingPathComponent("DailyBrief", isDirectory: true)
    }

    func storageURL() -> URL {
        guard let data = defaults.data(forKey: Keys.storageBookmark) else {
            return defaultStorageURL
        }

        var isStale = false
        do {
            let url = try URL(
                resolvingBookmarkData: data,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            if isStale {
                try saveStorageURL(url)
            }

            return url
        } catch {
            return defaultStorageURL
        }
    }

    func saveStorageURL(_ url: URL) throws {
        let data = try url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
        defaults.set(data, forKey: Keys.storageBookmark)
    }

    func clearCustomStorageURL() {
        defaults.removeObject(forKey: Keys.storageBookmark)
    }
}
