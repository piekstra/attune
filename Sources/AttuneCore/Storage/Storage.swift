import Foundation

/// All persistence is plain JSON in Application Support. No network, no
/// analytics, no cloud — the check-in history describes someone's attention
/// and body states across their workday, which is health-adjacent data and
/// stays on their machine. See README "Privacy".
public enum StoragePaths {
    public static func appSupportDirectory(
        fileManager: FileManager = .default
    ) throws -> URL {
        let base = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dir = base.appendingPathComponent("Attune", isDirectory: true)
        try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}

/// Load/save of the check-in history. Kept synchronous and simple: the file
/// is small (history is capped) and writes happen at human speed.
public final class HistoryStore {
    private let fileURL: URL
    private let maxEntries: Int
    private var cache: [CheckIn]

    public init(fileURL: URL, maxEntries: Int = 5000) {
        self.fileURL = fileURL
        self.maxEntries = maxEntries
        self.cache = Self.load(from: fileURL)
    }

    /// Store rooted in the default Application Support location.
    public convenience init(maxEntries: Int = 5000) throws {
        let dir = try StoragePaths.appSupportDirectory()
        self.init(
            fileURL: dir.appendingPathComponent("history.json"),
            maxEntries: maxEntries
        )
    }

    public var all: [CheckIn] { cache }

    public func append(_ checkIn: CheckIn) {
        cache.append(checkIn)
        if cache.count > maxEntries {
            cache.removeFirst(cache.count - maxEntries)
        }
        persist()
    }

    public func recent(days: Int, from now: Date = Date()) -> [CheckIn] {
        let cutoff = now.addingTimeInterval(-Double(days) * 24 * 3600)
        return cache.filter { $0.date >= cutoff }
    }

    private func persist() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(cache)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // Persistence failure should never take the app down; the
            // in-memory session keeps working.
            NSLog("Attune: failed to save history: \(error)")
        }
    }

    private static func load(from url: URL) -> [CheckIn] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([CheckIn].self, from: data)) ?? []
    }
}

/// Settings persistence, same pattern.
public final class SettingsStore {
    private let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public convenience init() throws {
        let dir = try StoragePaths.appSupportDirectory()
        self.init(fileURL: dir.appendingPathComponent("settings.json"))
    }

    public func load() -> UserSettings {
        guard let data = try? Data(contentsOf: fileURL),
              let settings = try? JSONDecoder().decode(UserSettings.self, from: data)
        else { return .default }
        return settings
    }

    public func save(_ settings: UserSettings) {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(settings)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            NSLog("Attune: failed to save settings: \(error)")
        }
    }
}
