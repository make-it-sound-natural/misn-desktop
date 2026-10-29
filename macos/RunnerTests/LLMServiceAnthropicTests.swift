import XCTest
@testable import Make_It_Sound_Natural

final class LLMServiceAnthropicTests: XCTestCase {
    private let endTurn = #"""
    {"type":"message","role":"assistant","content":[{"type":"text","text":"{\"balanced\":\"b\",\"casual\":\"c\",\"formal\":\"f\",\"concise\":\"n\"}"}],"stop_reason":"end_turn"}
    """#

    override func tearDown() {
        AnthropicURLProtocol.handler = nil
        super.tearDown()
    }

    func testRewriteSendsOneMessagesRequestAndReturnsVariants() {
        let outcome = run(responses: [(200, endTurn)])

        XCTAssertEqual(outcome.requests.count, 1)
        XCTAssertEqual(
            outcome.requests.first?.url?.absoluteString,
            "https://api.anthropic.com/v1/messages"
        )
        XCTAssertEqual(
            outcome.content,
            "---BALANCED---\nb\n\n---CASUAL---\nc\n\n" +
            "---FORMAL---\nf\n\n---CONCISE---\nn"
        )
        XCTAssertEqual(outcome.variantOrError, "b")
        XCTAssertNil(outcome.delegate.error)
    }

    func testInvalidKeyReportsAuthenticationFailure() {
        let body = """
        {"type":"error","error":{"type":"authentication_error","message":"invalid x-api-key"}}
        """
        let outcome = run(responses: [(401, body)])

        XCTAssertEqual(outcome.requests.count, 1)
        XCTAssertEqual(outcome.delegate.error, "invalid x-api-key")
        XCTAssertTrue(outcome.delegate.isAuthenticationFailure)
        XCTAssertEqual(outcome.delegate.provider, "anthropic-messages")
    }

    func testParameterRejectionIsNotRetried() {
        let body = """
        {"type":"error","error":{"type":"invalid_request_error","message":"response_format is not supported"}}
        """
        let outcome = run(responses: [(400, body)])

        XCTAssertEqual(outcome.requests.count, 1)
        XCTAssertEqual(outcome.delegate.error, "response_format is not supported")
        XCTAssertEqual(outcome.variantOrError, "response_format is not supported")
        XCTAssertFalse(outcome.delegate.isAuthenticationFailure)
    }

    func testRateLimitAndServerErrorsShowBodyMessageWithoutRetry() {
        let errors = [
            (429, "rate_limit_error", "Number of requests has exceeded your rate limit"),
            (500, "api_error", "Internal server error"),
            (529, "overloaded_error", "Overloaded")
        ]
        for (status, type, message) in errors {
            let body = """
            {"type":"error","error":{"type":"\(type)","message":"\(message)"}}
            """
            let outcome = run(responses: [(status, body)])

            XCTAssertEqual(outcome.requests.count, 1, "\(status)")
            XCTAssertEqual(outcome.delegate.error, message, "\(status)")
            XCTAssertNil(outcome.content, "\(status)")
        }
    }

    func testRefusalReportsDeclinedMessageWithoutContent() {
        let body = """
        {"type":"message","role":"assistant","content":[],"stop_reason":"refusal",\
        "stop_details":{"type":"refusal","category":"cyber"}}
        """
        let outcome = run(responses: [(200, body)])

        XCTAssertEqual(outcome.requests.count, 1)
        XCTAssertEqual(
            outcome.delegate.error,
            "Claude declined to rewrite this text."
        )
        XCTAssertFalse(outcome.delegate.isAuthenticationFailure)
        XCTAssertNil(outcome.content)
        XCTAssertEqual(
            outcome.variantOrError,
            "Claude declined to rewrite this text."
        )
    }

    func testMissingAnthropicKeyFailsBeforeAnyRequest() {
        let outcome = run(responses: [], anthropicApiKey: "  ")

        XCTAssertEqual(outcome.requests.count, 0)
        XCTAssertEqual(
            outcome.delegate.error,
            "Add an API key for the selected provider in Settings."
        )
        XCTAssertEqual(
            outcome.variantOrError,
            "Add an API key for the selected provider in Settings."
        )
    }

    private struct Outcome {
        let requests: [URLRequest]
        let delegate: CapturingDelegate
        let content: String?
        let variantOrError: String?
    }

    private func run(
        responses: [(Int, String)],
        anthropicApiKey: String = "anthropic-key"
    ) -> Outcome {
        var requests: [URLRequest] = []
        AnthropicURLProtocol.handler = { request in
            requests.append(request)
            let index = requests.count - 1
            guard index < responses.count else {
                XCTFail("Unexpected extra request")
                return (500, "{}")
            }
            return responses[index]
        }
        let sessionConfig = URLSessionConfiguration.ephemeral
        sessionConfig.protocolClasses = [AnthropicURLProtocol.self]
        let session = URLSession(configuration: sessionConfig)
        defer { session.invalidateAndCancel() }
        let service = LLMService(session: session)
        let delegate = CapturingDelegate()
        service.delegate = delegate
        var content: String?
        var variantOrError: String?
        let done = expectation(description: "Request completes once")
        done.assertForOverFulfill = true
        service.processText("Original text", config: .init(
            provider: AppDefaults.anthropicProvider,
            apiKey: "openai-key",
            openRouterApiKey: "router-key",
            anthropicApiKey: anthropicApiKey,
            customProviderApiKey: "custom-key",
            customProviderBaseUrl: nil,
            model: "claude-haiku-5-5",
            customPrompt: nil,
            context: nil,
            targetProfileInstruction: nil,
            screenshotAttachment: nil,
            accessibilityContext: nil
        )) { receivedContent, receivedVariantOrError in
            content = receivedContent
            variantOrError = receivedVariantOrError
            done.fulfill()
        }
        wait(for: [done], timeout: 3)
        return Outcome(
            requests: requests,
            delegate: delegate,
            content: content,
            variantOrError: variantOrError
        )
    }
}

private final class CapturingDelegate: LLMServiceDelegate {
    var error: String?
    var provider: String?
    var isAuthenticationFailure = false

    func llmService(
        _ service: LLMService,
        didFailWithError error: String,
        isAuthenticationFailure: Bool,
        provider: String
    ) {
        self.error = error
        self.provider = provider
        self.isAuthenticationFailure = isAuthenticationFailure
    }

    func llmService(
        _ service: LLMService,
        didReceiveTimingData: (String, TimeInterval)
    ) {}
}

private final class AnthropicURLProtocol: URLProtocol {
    static var handler: ((URLRequest) -> (Int, String))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler, let url = request.url else { return }
        let (status, body) = handler(request)
        guard let response = HTTPURLResponse(
            url: url, statusCode: status, httpVersion: nil, headerFields: nil
        ) else { return }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
