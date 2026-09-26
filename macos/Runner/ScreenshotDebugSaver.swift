import Foundation

final class ScreenshotDebugSaver {
    private let environment: [String: String]
    private let store: DebugArtifactStore

    init(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        outputDirectory: URL? = nil,
        maxFiles: Int = 20,
        fileManager: FileManager = .default
    ) {
        self.environment = environment
        self.store = DebugArtifactStore(
            directoryEnvironmentKey: "MISN_SCREENSHOT_CONTEXT_DIR",
            defaultDirectoryName: "DebugScreenshotContext",
            environment: environment,
            outputDirectory: outputDirectory,
            maxFiles: maxFiles,
            fileManager: fileManager
        )
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
            let fileURL = try store.write(
                data,
                nameSuffix: "\(mode.rawValue).jpg"
            )
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

    private func debugLog(_ message: String) {
        #if DEBUG
        print(message)
        #endif
    }
}
