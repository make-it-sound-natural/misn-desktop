import FlutterMacOS
import XCTest
@testable import Make_It_Sound_Natural

final class RewritePreflightTests: XCTestCase {
    func testEmptyModelBlocksWithChooseModelMessage() {
        XCTAssertEqual(
            RewritePreflight.blockingMessage(
                model: "",
                requiresTargetProfileSelection: false
            ),
            "Choose a model in Settings."
        )
    }

    func testWhitespaceModelBlocks() {
        XCTAssertEqual(
            RewritePreflight.blockingMessage(
                model: " \n\t ",
                requiresTargetProfileSelection: false
            ),
            RewritePreflight.missingModelMessage
        )
    }

    func testMissingModelTakesPriorityOverTargetProfile() {
        XCTAssertEqual(
            RewritePreflight.blockingMessage(
                model: "",
                requiresTargetProfileSelection: true
            ),
            RewritePreflight.missingModelMessage
        )
    }

    func testMissingTargetProfileBlocksWhenModelIsSet() {
        XCTAssertEqual(
            RewritePreflight.blockingMessage(
                model: "gpt-6-sol",
                requiresTargetProfileSelection: true
            ),
            "Choose a target language before rewriting."
        )
    }

    func testModelAndProfilePass() {
        XCTAssertNil(
            RewritePreflight.blockingMessage(
                model: "gpt-6-sol",
                requiresTargetProfileSelection: false
            )
        )
    }

    func testGenerateVariantsWithEmptyModelSendsErrorAndOpensSettings() {
        let errorReceived = expectation(description: "Flutter receives error")
        let settingsOpened = expectation(description: "Flutter opens Settings")
        let messenger = RecordingPreflightMessenger { call in
            switch call.method {
            case "onError":
                XCTAssertEqual(
                    call.arguments as? String,
                    RewritePreflight.missingModelMessage
                )
                errorReceived.fulfill()
            case "openSettings":
                settingsOpened.fulfill()
            default:
                XCTFail("Unexpected Flutter method: \(call.method)")
            }
        }
        let channel = MethodChannelHandler(binaryMessenger: messenger)
        channel.model = ""
        let handler = ShortcutHandler(
            methodChannelHandler: channel,
            statusBubble: MockStatusBubble()
        )
        var completed = false

        channel.onGenerateVariants?("Hello") { content, error in
            completed = true
            XCTAssertNil(content)
            XCTAssertEqual(error, RewritePreflight.missingModelMessage)
        }

        XCTAssertTrue(completed, "Missing model must fail before any LLM work")
        wait(for: [errorReceived, settingsOpened], timeout: 2)
        withExtendedLifetime(handler) {}
    }
}

private final class RecordingPreflightMessenger: NSObject,
    FlutterBinaryMessenger {
    init(onMethod: @escaping (FlutterMethodCall) -> Void) {
        self.onMethod = onMethod
    }

    private let onMethod: (FlutterMethodCall) -> Void

    func send(onChannel channel: String, message: Data?) {
        guard let message = message else {
            XCTFail("Flutter method message must not be empty")
            return
        }
        onMethod(FlutterStandardMethodCodec.sharedInstance()
            .decodeMethodCall(message))
    }

    func send(
        onChannel channel: String,
        message: Data?,
        binaryReply callback: FlutterBinaryReply?
    ) {
        send(onChannel: channel, message: message)
        callback?(nil)
    }

    func setMessageHandlerOnChannel(
        _ channel: String,
        binaryMessageHandler handler: FlutterBinaryMessageHandler?
    ) -> FlutterBinaryMessengerConnection {
        1
    }

    func cleanUpConnection(_ connection: FlutterBinaryMessengerConnection) {}
}
