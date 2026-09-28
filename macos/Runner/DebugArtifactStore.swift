import Foundation

/// Where a DEBUG-only context saver writes its files, and how many it keeps.
/// Shared by `ScreenshotDebugSaver` and `AccessibilityContextDebugSaver`.
struct DebugArtifactStore {
    /// Environment variable that replaces the default output directory.
    private let directoryEnvironmentKey: String
    /// Folder under `Application Support/<app>` used without an override.
    private let defaultDirectoryName: String
    private let environment: [String: String]
    private let outputDirectoryOverride: URL?
    private let maxFiles: Int
    private let fileManager: FileManager
    private let now: () -> Date

    init(
        directoryEnvironmentKey: String,
        defaultDirectoryName: String,
        environment: [String: String],
        outputDirectory: URL?,
        maxFiles: Int,
        fileManager: FileManager,
        now: @escaping () -> Date = Date.init
    ) {
        self.directoryEnvironmentKey = directoryEnvironmentKey
        self.defaultDirectoryName = defaultDirectoryName
        self.environment = environment
        self.outputDirectoryOverride = outputDirectory
        self.maxFiles = maxFiles
        self.fileManager = fileManager
        self.now = now
    }

    /// Writes `data` as `<timestamp>-<nameSuffix>` and deletes the oldest
    /// files beyond `maxFiles`.
    func write(_ data: Data, nameSuffix: String) throws -> URL {
        let directory = try outputDirectory()
        let fileURL = directory.appendingPathComponent(
            "\(timestamp())-\(nameSuffix)"
        )
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        try data.write(to: fileURL)
        try prune(directory: directory)
        return fileURL
    }

    private func outputDirectory() throws -> URL {
        if let outputDirectoryOverride {
            return outputDirectoryOverride
        }
        if let override = environment[directoryEnvironmentKey],
           !override.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return URL(fileURLWithPath: override, isDirectory: true)
        }
        let base = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return base
            .appendingPathComponent(AppDefaults.appName, isDirectory: true)
            .appendingPathComponent(defaultDirectoryName, isDirectory: true)
    }

    private func timestamp() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: now())
            .replacingOccurrences(of: ":", with: "-")
    }

    private func prune(directory: URL) throws {
        let files = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        )
        guard files.count > maxFiles else { return }

        let sorted = files.sorted { lhs, rhs in
            let leftDate = (
                try? lhs.resourceValues(forKeys: [.creationDateKey])
                    .creationDate
            ) ?? .distantPast
            let rightDate = (
                try? rhs.resourceValues(forKeys: [.creationDateKey])
                    .creationDate
            ) ?? .distantPast
            return leftDate < rightDate
        }

        for file in sorted.prefix(files.count - maxFiles) {
            try? fileManager.removeItem(at: file)
        }
    }
}
