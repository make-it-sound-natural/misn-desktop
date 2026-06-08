import Foundation

final class ScreenshotDebugSaver {
    private let environment: [String: String]
    private let outputDirectoryOverride: URL?
    private let maxFiles: Int
    private let fileManager: FileManager

    init(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        outputDirectory: URL? = nil,
        maxFiles: Int = 20,
        fileManager: FileManager = .default
    ) {
        self.environment = environment
        self.outputDirectoryOverride = outputDirectory
        self.maxFiles = maxFiles
        self.fileManager = fileManager
    }

    func saveIfEnabled(
        attachment: LLMService.ScreenshotAttachment,
        mode: ScreenshotContextMode
    ) -> URL? {
        #if DEBUG
        guard environment["MISN_SAVE_SCREENSHOT_CONTEXT"] == "1" else {
            debugLog(
                "Screenshot debug save disabled. Set " +
                "MISN_SAVE_SCREENSHOT_CONTEXT=1"
            )
            return nil
        }
        guard let data = Data(base64Encoded: attachment.base64Data) else {
            debugLog("Screenshot debug save failed: invalid base64")
            return nil
        }

        do {
            let directory = try outputDirectory()
            let fileURL = directory.appendingPathComponent(
                filenameForNow(mode: mode)
            )
            try fileManager.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
            try data.write(to: fileURL)
            try prune(directory: directory)
            debugLog("Screenshot debug saved: \(fileURL.path)")
            return fileURL
        } catch {
            debugLog("Screenshot debug save failed: \(error)")
            return nil
        }
        #else
        return nil
        #endif
    }

    private func outputDirectory() throws -> URL {
        if let outputDirectoryOverride {
            return outputDirectoryOverride
        }
        if let override = environment["MISN_SCREENSHOT_CONTEXT_DIR"],
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
            .appendingPathComponent("DebugScreenshotContext", isDirectory: true)
    }

    private func filenameForNow(mode: ScreenshotContextMode) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let timestamp = formatter.string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        return "\(timestamp)-\(mode.rawValue).jpg"
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

    private func debugLog(_ message: String) {
        #if DEBUG
        print(message)
        #endif
    }
}
