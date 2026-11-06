import XCTest
@testable import Make_It_Sound_Natural

final class LLMServiceOpenAIResponsesTests: XCTestCase {
    override func tearDown() {
        ResponsesURLProtocol.handler = nil
        super.tearDown()
    }

    private let success = #"""
    {
      "status": "completed",
      "incomplete_details": null,
      "output": [
        {"type": "reasoning", "content": null, "summary": []},
        {"type": "message", "content": [{
          "type": "output_text", "annotations": [],
          "text": "{\"balanced\":\"b\",\"casual\":\"c\",\"formal\":\"f\",\"concise\":\"n\"}"
        }]}
      ]
    }
    """#

    func testRewriteSendsOneResponsesRequestAndReturnsVariants() {
        let outcome = run(responses: [(200, success)])

        XCTAssertEqual(outcome.requests.count, 1)
        XCTAssertEqual(
            outcome.requests.first?.url?.absoluteString,
            "https://api.openai.com/v1/responses"
        )
        XCTAssertEqual(
            outcome.content,
            "---BALANCED---\nb\n\n---CASUAL---\nc\n\n" +
            "---FORMAL---\nf\n\n---CONCISE---\nn"
        )
        XCTAssertEqual(outcome.variantOrError, "b")
        XCTAssertNil(outcome.delegate.error)
    }

    func testFasterTierRateLimitShowsProviderMessageWithoutRetry() throws {
        let message = "Ultrafast rate limit reached."
        let body = #"{"error":{"message":"Ultrafast rate limit reached."}}"#
        let outcome = run(responses: [(429, body)], speed: .ultrafast)

        XCTAssertEqual(outcome.requests.count, 1)
        let data = try XCTUnwrap(outcome.requests.first?.httpBody)
        let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(payload["service_tier"] as? String, "ultrafast")
        XCTAssertNil(outcome.content)
        XCTAssertEqual(outcome.variantOrError, message)
        XCTAssertEqual(outcome.delegate.error, message)
        XCTAssertEqual(outcome.delegate.provider, AppDefaults.openAiProvider)
        XCTAssertFalse(outcome.delegate.isAuthenticationFailure)
    }

    func testReasoningRejectionRetriesWithoutReasoningAndReturnsVariants() throws {
        let rejections = [
            ("gpt-4.1", "reasoning", "unsupported_parameter"),
            ("gpt-4o-mini", "reasoning", "unsupported_parameter"),
            ("custom-reasoning-model", "reasoning.effort", "unsupported_value")
        ]
        for status in [400, 422] {
            for (model, parameter, code) in rejections {
                let error = """
                {"error":{"param":"\(parameter)","code":"\(code)",
                "message":"Unsupported parameter or value: \(parameter)"}}
                """
                let outcome = run(
                    responses: [(status, error), (200, success)],
                    speed: .ultrafast, model: model
                )
                XCTAssertEqual(outcome.requests.count, 2)
                guard outcome.requests.count == 2 else { continue }
                let first = try payload(outcome.requests[0])
                let second = try payload(outcome.requests[1])
                XCTAssertEqual(
                    first["reasoning"] as? [String: String], ["effort": "none"]
                )
                var expected = first
                expected.removeValue(forKey: "reasoning")
                XCTAssertEqual(second as NSDictionary, expected as NSDictionary)
                XCTAssertEqual(second["service_tier"] as? String, "ultrafast")
                XCTAssertNotNil(outcome.content)
                XCTAssertEqual(outcome.variantOrError, "b")
                XCTAssertNil(outcome.delegate.error)
            }
        }
    }

    func testSecondReasoningRejectionIsShownWithoutAnotherRetry() throws {
        let message = "Unsupported value for reasoning.effort"
        let error = """
        {"error":{"param":"reasoning.effort","code":"unsupported_value",
        "message":"\(message)"}}
        """
        let outcome = run(responses: [(400, error), (422, error)])

        XCTAssertEqual(outcome.requests.count, 2)
        if outcome.requests.count == 2 {
            XCTAssertNil(try payload(outcome.requests[1])["reasoning"])
        }
        XCTAssertNil(outcome.content)
        XCTAssertEqual(outcome.variantOrError, message)
        XCTAssertEqual(outcome.delegate.error, message)
    }

    func testServiceTierRejectionIsShownWithoutRetry() throws {
        let message = "Unsupported value for service_tier"
        let error = """
        {"error":{"param":"service_tier","code":"unsupported_value",
        "message":"\(message)"}}
        """
        for speed in [RequestSpeed.fast, .ultrafast] {
            for status in [400, 422] {
                let outcome = run(responses: [(status, error)], speed: speed)
                XCTAssertEqual(outcome.requests.count, 1)
                let request = try XCTUnwrap(outcome.requests.first)
                XCTAssertEqual(
                    try payload(request)["service_tier"] as? String,
                    speed.rawValue
                )
                XCTAssertNil(outcome.content)
                XCTAssertEqual(outcome.variantOrError, message)
                XCTAssertEqual(outcome.delegate.error, message)
            }
        }
    }

    private func payload(_ request: URLRequest) throws -> [String: Any] {
        let body = try XCTUnwrap(request.httpBody)
        return try XCTUnwrap(
            JSONSerialization.jsonObject(with: body) as? [String: Any]
        )
    }

    private struct Outcome {
        let requests: [URLRequest]
        let content: String?
        let variantOrError: String?
        let delegate: ResponsesCapturingDelegate
    }

    private func run(
        responses: [(Int, String)],
        speed: RequestSpeed = .standard,
        model: String = "gpt-6.1-sol"
    ) -> Outcome {
        var requests: [URLRequest] = []
        ResponsesURLProtocol.handler = { request in
            var captured = request
            if captured.httpBody == nil, let stream = request.httpBodyStream {
                stream.open()
                defer { stream.close() }
                var data = Data()
                var buffer = [UInt8](repeating: 0, count: 4096)
                while stream.hasBytesAvailable {
                    let count = stream.read(&buffer, maxLength: buffer.count)
                    guard count > 0 else { break }
                    data.append(buffer, count: count)
                }
                captured.httpBody = data
            }
            requests.append(captured)
            let index = requests.count - 1
            guard index < responses.count else {
                XCTFail("Unexpected extra request")
                return (500, "{}")
            }
            return responses[index]
        }
        let sessionConfig = URLSessionConfiguration.ephemeral
        sessionConfig.protocolClasses = [ResponsesURLProtocol.self]
        let session = URLSession(configuration: sessionConfig)
        defer { session.invalidateAndCancel() }
        let service = LLMService(session: session)
        let delegate = ResponsesCapturingDelegate()
        service.delegate = delegate
        var content: String?
        var variantOrError: String?
        let done = expectation(description: "Request completes once")
        done.assertForOverFulfill = true
        service.processText("Original text", config: .init(
            provider: AppDefaults.openAiProvider,
            apiKey: "openai-key", openRouterApiKey: "", customProviderApiKey: "",
            customProviderBaseUrl: nil, model: model, customPrompt: nil,
            context: nil, targetProfileInstruction: nil, screenshotAttachment: nil,
            accessibilityContext: nil, reasoningEffort: .none,
            requestSpeed: speed
        )) { receivedContent, receivedVariantOrError in
            content = receivedContent
            variantOrError = receivedVariantOrError
            done.fulfill()
        }
        wait(for: [done], timeout: 3)
        return Outcome(
            requests: requests, content: content, variantOrError: variantOrError,
            delegate: delegate
        )
    }
}

private final class ResponsesCapturingDelegate: LLMServiceDelegate {
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

private final class ResponsesURLProtocol: URLProtocol {
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
