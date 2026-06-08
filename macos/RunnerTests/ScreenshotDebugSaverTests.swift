import XCTest
@testable import Make_It_Sound_Natural

final class ScreenshotDebugSaverTests: XCTestCase {
    func testDisabledSaverDoesNotWriteFile() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let saver = ScreenshotDebugSaver(
            environment: [:],
            outputDirectory: directory,
            maxFiles: 20
        )
        let attachment = LLMService.ScreenshotAttachment(
            mimeType: "image/jpeg",
            base64Data: Data("image".utf8).base64EncodedString()
        )

        let savedURL = saver.saveIfEnabled(
            attachment: attachment,
            mode: .fullScreen
        )

        XCTAssertNil(savedURL)
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path))
    }

    func testEnabledSaverWritesImageFile() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let saver = ScreenshotDebugSaver(
            environment: ["MISN_SAVE_SCREENSHOT_CONTEXT": "1"],
            outputDirectory: directory,
            maxFiles: 20
        )
        let attachment = LLMService.ScreenshotAttachment(
            mimeType: "image/jpeg",
            base64Data: Data("image".utf8).base64EncodedString()
        )

        let savedURL = saver.saveIfEnabled(
            attachment: attachment,
            mode: .activeApplication
        )

        let files = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )
        XCTAssertEqual(files.count, 1)
        XCTAssertTrue(files[0].lastPathComponent.contains("activeApplication"))
        guard let savedURL else {
            XCTFail("Expected saved screenshot URL")
            return
        }
        XCTAssertEqual(
            savedURL.resolvingSymlinksInPath(),
            files[0].resolvingSymlinksInPath()
        )
        XCTAssertTrue(FileManager.default.fileExists(atPath: savedURL.path))
        try FileManager.default.removeItem(at: directory)
    }

    func testEnabledSaverReturnsNilForInvalidBase64() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let saver = ScreenshotDebugSaver(
            environment: ["MISN_SAVE_SCREENSHOT_CONTEXT": "1"],
            outputDirectory: directory,
            maxFiles: 20
        )
        let attachment = LLMService.ScreenshotAttachment(
            mimeType: "image/jpeg",
            base64Data: "not-valid-base64"
        )

        let savedURL = saver.saveIfEnabled(
            attachment: attachment,
            mode: .fullScreen
        )

        XCTAssertNil(savedURL)
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path))
    }

    func testEnabledSaverKeepsLatestFilesOnly() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let saver = ScreenshotDebugSaver(
            environment: ["MISN_SAVE_SCREENSHOT_CONTEXT": "1"],
            outputDirectory: directory,
            maxFiles: 2
        )
        let attachment = LLMService.ScreenshotAttachment(
            mimeType: "image/jpeg",
            base64Data: Data("image".utf8).base64EncodedString()
        )

        _ = saver.saveIfEnabled(attachment: attachment, mode: .fullScreen)
        _ = saver.saveIfEnabled(attachment: attachment, mode: .fullScreen)
        _ = saver.saveIfEnabled(attachment: attachment, mode: .fullScreen)

        let files = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )
        XCTAssertLessThanOrEqual(files.count, 2)
        try FileManager.default.removeItem(at: directory)
    }
}
