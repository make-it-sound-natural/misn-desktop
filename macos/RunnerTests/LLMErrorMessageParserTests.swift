import XCTest
@testable import Make_It_Sound_Natural

final class LLMErrorMessageParserTests: XCTestCase {

    func testNilOrEmptyBodyReturnsHttpStatus() {
        XCTAssertEqual(
            LLMErrorMessageParser.userMessage(from: nil, statusCode: 402),
            "HTTP Error: 402"
        )
        XCTAssertEqual(
            LLMErrorMessageParser.userMessage(from: Data(), statusCode: 500),
            "HTTP Error: 500"
        )
    }

    func testOpenRouterStyleNestedMessageAndNumericCode() {
        let json = """
        {"error":{"message":"Need more credits","code":402,"metadata":{}}}
        """
        let data = Data(json.utf8)
        let msg = LLMErrorMessageParser.userMessage(from: data, statusCode: 402)
        XCTAssertTrue(msg.contains("credits"), "Expected provider message: \(msg)")
    }

    func testNumeric402WhenMessageEmptyUsesMappedString() {
        let json = #"{"error":{"code":402,"message":""}}"#
        let data = Data(json.utf8)
        let msg = LLMErrorMessageParser.userMessage(from: data, statusCode: 402)
        XCTAssertEqual(
            msg,
            "Insufficient credits or quota. Check your provider account."
        )
    }

    func testOpenAIStringCodes() {
        let json = #"{"error":{"code":"invalid_api_key"}}"#
        let data = Data(json.utf8)
        let msg = LLMErrorMessageParser.userMessage(from: data, statusCode: 401)
        XCTAssertEqual(msg, "Invalid API key. Check settings.")
    }

    func testInvalidApiKeyIsAuthenticationFailure() {
        let json = #"{"error":{"code":"invalid_api_key"}}"#
        let data = json.data(using: .utf8)

        let parsed = LLMErrorMessageParser.errorInfo(
            from: data,
            statusCode: 401
        )

        XCTAssertEqual(parsed.message, "Invalid API key. Check settings.")
        XCTAssertTrue(parsed.isAuthenticationFailure)
    }

    func testQuotaErrorIsNotAuthenticationFailure() {
        let json = #"{"error":{"code":402}}"#
        let data = json.data(using: .utf8)

        let parsed = LLMErrorMessageParser.errorInfo(
            from: data,
            statusCode: 402
        )

        XCTAssertFalse(parsed.isAuthenticationFailure)
    }

    func testTopLevelErrorString() {
        let json = #"{"error":"Simple provider error"}"#
        let data = Data(json.utf8)
        let msg = LLMErrorMessageParser.userMessage(from: data, statusCode: 400)
        XCTAssertEqual(msg, "Simple provider error")
    }

    func testTruncationLongMessage() {
        let long = String(repeating: "a", count: 250)
        let json = #"{"error":{"message":"\#(long)"}}"#
        let data = Data(json.utf8)
        let msg = LLMErrorMessageParser.userMessage(from: data, statusCode: 400)
        XCTAssertEqual(msg.count, LLMErrorMessageParser.maxUserErrorLength)
        XCTAssertTrue(msg.hasSuffix("…"))
    }

    func testProviderUnsupportedImageMessageSurfaces() {
        let json = """
        {
          "error": {
            "message": "Model does not support image input",
            "code": 400
          }
        }
        """
        let data = Data(json.utf8)

        let msg = LLMErrorMessageParser.userMessage(
            from: data,
            statusCode: 400
        )

        XCTAssertEqual(msg, "Model does not support image input")
    }

    func testTokenGuardImagePayloadErrorSurfacesProviderMessage() {
        let json = """
        {"error":{"message":"Failed to deserialize the JSON body into the target type: messages[1]: unknown variant image_url, expected text","type":"invalid_request_error"}}
        """

        let msg = LLMErrorMessageParser.userMessage(
            from: Data(json.utf8),
            statusCode: 400
        )

        XCTAssertTrue(msg.contains("unknown variant image_url"))
    }

    func testInvalidJsonFallsBackToHttp() {
        let data = Data("{not-json".utf8)
        XCTAssertEqual(
            LLMErrorMessageParser.userMessage(from: data, statusCode: 503),
            "HTTP Error: 503"
        )
    }
}
