import Foundation

/// Reads and atomically writes `configuration.json`.
///
/// A file that cannot be loaded puts the store in read-only recovery: the original is never
/// overwritten until the user explicitly resets, which first moves it to a backup.
public final class ConfigurationStore {
    public enum LoadResult: Equatable, Sendable {
        case firstRun
        case loaded(Configuration)
        case recovery(ConfigurationError)
    }

    public enum SaveError: Error, Equatable, Sendable {
        case readOnlyRecovery
        case writeFailed
    }

    public let fileURL: URL
    public private(set) var isReadOnly = false
    private let fileManager = FileManager.default

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    /// `~/Library/Application Support/<bundle-id>/configuration.json`.
    public static func defaultFileURL(bundleID: String) -> URL {
        URL.applicationSupportDirectory
            .appending(path: bundleID, directoryHint: .isDirectory)
            .appending(path: "configuration.json", directoryHint: .notDirectory)
    }

    public func load() -> LoadResult {
        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            isReadOnly = false
            return .firstRun
        } catch {
            isReadOnly = true
            return .recovery(.invalid("unreadable"))
        }

        do {
            let configuration = try Self.decode(data)
            isReadOnly = false
            return .loaded(configuration)
        } catch {
            isReadOnly = true
            return .recovery(error)
        }
    }

    static func decode(_ data: Data) throws(ConfigurationError) -> Configuration {
        struct VersionProbe: Decodable { var schemaVersion: Int }
        let decoder = JSONDecoder()
        guard let probe = try? decoder.decode(VersionProbe.self, from: data) else {
            throw .invalid("unreadable")
        }
        if probe.schemaVersion > Configuration.currentSchemaVersion {
            throw .unsupportedVersion(probe.schemaVersion)
        }
        guard let configuration = try? decoder.decode(Configuration.self, from: data) else {
            throw .invalid("unexpected structure")
        }
        try configuration.validate()
        return configuration
    }

    static func encode(_ configuration: Configuration) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(configuration)
    }

    /// Writes to a temporary file in the same directory, then renames it over the original.
    public func save(_ configuration: Configuration) throws(SaveError) {
        guard !isReadOnly else { throw .readOnlyRecovery }
        do {
            try configuration.validate()
            try write(Self.encode(configuration))
        } catch {
            throw .writeFailed
        }
    }

    /// Moves the current file (if any) to a timestamped backup and writes `configuration`.
    /// - Returns: the backup location, when a file existed.
    @discardableResult
    public func reset(to configuration: Configuration, now: Date = .now) throws(SaveError) -> URL? {
        var backupURL: URL?
        do {
            if fileManager.fileExists(atPath: fileURL.path) {
                let stamp = now.formatted(.iso8601.year().month().day().time(includingFractionalSeconds: false))
                    .replacingOccurrences(of: ":", with: "")
                let candidate = fileURL.deletingLastPathComponent()
                    .appending(path: "configuration.backup-\(stamp)-\(UUID().uuidString.prefix(8)).json")
                try fileManager.moveItem(at: fileURL, to: candidate)
                backupURL = candidate
            }
            try write(Self.encode(configuration))
        } catch {
            throw .writeFailed
        }
        isReadOnly = false
        return backupURL
    }

    private func write(_ data: Data) throws {
        let directory = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let temporaryURL = directory.appending(path: ".configuration-\(UUID().uuidString).tmp")
        do {
            try data.write(to: temporaryURL, options: [.withoutOverwriting])
            let handle = try FileHandle(forWritingTo: temporaryURL)
            // fsync on macOS doesn't flush the drive's cache; F_FULLFSYNC does where supported.
            if fcntl(handle.fileDescriptor, F_FULLFSYNC) != 0 { try handle.synchronize() }
            try handle.close()
            guard rename(temporaryURL.path, fileURL.path) == 0 else {
                throw CocoaError(.fileWriteUnknown)
            }
            // Flush the directory so the renamed entry survives a crash.
            let directoryDescriptor = open(directory.path, O_RDONLY)
            if directoryDescriptor >= 0 {
                fsync(directoryDescriptor)
                close(directoryDescriptor)
            }
        } catch {
            try? fileManager.removeItem(at: temporaryURL)
            throw error
        }
    }
}
