import XCTest
@testable import Make_It_Sound_Natural

final class LLMServiceCompatibilityTests: XCTestCase {
    private let reasoningError = """
    {"error":{"message":"Unsupported value: 'reasoning_effort' does not support 'none'"}}
    """
    private let formatError = """
    {"error":{"message":"response_format is not supported"}}
    """
    private let success = """
    {"choices":[{"message":{"content":"Rewritten text"}}]}
    """

    override func tearDown() {
        CompatibilityURLProtocol.handler = nil
        super.tearDown()
    }

    func testReasoningFallbackForEveryProviderPreservesRequest() throws {
        for provider in ["openai", "openrouter", "tokenguard", "custom-endpoint"] {
            let requests = try run(
                provider: provider,
                responses: [(400, reasoningError), (200, success)]
            )
            XCTAssertEqual(requests.count, 2)
            let original = try payload(requests[0])
            var expected = original
            expected.removeValue(forKey: "reasoning_effort")
            XCTAssertEqual(try payload(requests[1]) as NSDictionary, expected as NSDictionary)
            XCTAssertEqual(original["reasoning_effort"] as? String, "none")
            XCTAssertEqual(requests[0].url, requests[1].url)
            XCTAssertEqual(requests[0].httpMethod, requests[1].httpMethod)
            for header in ["Authorization", "Content-Type", "HTTP-Referer", "X-Title"] {
                XCTAssertEqual(
                    requests[0].value(forHTTPHeaderField: header),
                    requests[1].value(forHTTPHeaderField: header)
                )
            }
        }
    }

    func testBothFallbackOrdersKeepParametersRemovedAndPreserveContext() throws {
        for errors in [[reasoningError, formatError], [formatError, reasoningError]] {
            let requests = try run(responses: [
                (400, errors[0]), (400, errors[1]), (200, success)
            ])
            XCTAssertEqual(requests.count, 3)
            let original = try payload(requests[0])
            let intermediate = try payload(requests[1])
            if errors[0] == reasoningError {
                XCTAssertNil(intermediate["reasoning_effort"])
                XCTAssertNotNil(intermediate["response_format"])
            } else {
                XCTAssertNotNil(intermediate["reasoning_effort"])
                XCTAssertNil(intermediate["response_format"])
            }
            let final = try payload(requests[2])
            XCTAssertNil(final["reasoning_effort"])
            XCTAssertNil(final["response_format"])
            XCTAssertEqual(final["model"] as? String, original["model"] as? String)
            let before = try XCTUnwrap(original["messages"] as? [[String: Any]])
            let after = try XCTUnwrap(final["messages"] as? [[String: Any]])
            XCTAssertEqual(before[1] as NSDictionary, after[1] as NSDictionary)
            let systemBefore = try XCTUnwrap(before[0]["content"] as? String)
            let systemAfter = try XCTUnwrap(after[0]["content"] as? String)
            XCTAssertTrue(systemBefore.contains("Saved context"))
            XCTAssertTrue(systemBefore.contains("British English"))
            XCTAssertTrue(systemAfter.hasPrefix(systemBefore))
            XCTAssertEqual(systemAfter.components(
                separatedBy: "<provider_compatibility_output_format>"
            ).count, 2)
            XCTAssertTrue(systemAfter.contains("ONLY a valid JSON object"))
        }
    }

    func testFormatFallbackAlonePreservesReasoning() throws {
        let requests = try run(responses: [(400, formatError), (200, success)])
        XCTAssertEqual(requests.count, 2)
        XCTAssertEqual(try payload(requests[1])["reasoning_effort"] as? String, "none")
        XCTAssertNil(try payload(requests[1])["response_format"])
    }

    func testStructuredParameterRejectionAndLongErrorAreRecognized() throws {
        let bodies = [
            """
            {"error":{"param":"reasoning_effort","code":"unsupported_value"}}
            """,
            """
            {"error":{"message":"\(String(repeating: "Details. ", count: 40))reasoning_effort is unsupported"}}
            """,
            """
            {"error":"Unknown parameter: reasoning_effort"}
            """,
            """
            {"error":{"message":"This model does not support reasoning_effort"}}
            """
        ]
        for body in bodies {
            let requests = try run(responses: [(422, body), (200, success)])
            XCTAssertEqual(requests.count, 2)
            XCTAssertNil(try payload(requests[1])["reasoning_effort"])
        }
    }

    func testNoRetryForUnrelatedErrorsOrNonValidationStatuses() throws {
        var responses = [
            (400, #"{"error":{"message":"Invalid model"}}"#),
            (400, #"{"error":{"message":"context length exceeded"}}"#),
            (400, #"{"error":{"message":"reasoning_effort quota exceeded"}}"#),
            (400, #"{"error":{"param":"model","message":"Invalid value; reasoning_effort is low"}}"#),
            (400, #"{"error":{"code":"invalid_api_key","message":"reasoning_effort unsupported"}}"#),
            (400, #"{"error":{"message":"Invalid value for temperature; reasoning_effort is low"}}"#),
            (400, #"{"error":{"message":"Invalid schema for response_format"}}"#),
            (400, "not JSON")
        ]
        for status in [401, 402, 403, 404, 429, 500, 503] {
            responses.append((status, reasoningError))
            responses.append((status, formatError))
        }
        for response in responses {
            let requests = try run(responses: [response], expectSuccess: false)
            XCTAssertEqual(requests.count, 1, "Unexpected retry for \(response)")
        }
    }

    func testRepeatedRejectionStopsAfterParameterWasRemoved() throws {
        let requests = try run(
            responses: [(400, reasoningError), (400, reasoningError)],
            expectSuccess: false
        )
        XCTAssertEqual(requests.count, 2)
        let both = try run(
            responses: [(400, reasoningError), (400, formatError), (400, formatError)],
            expectSuccess: false
        )
        XCTAssertEqual(both.count, 3)
    }

    func testSimultaneousRejectionsNeedOnlyOneRetry() throws {
        let body = #"{"error":{"message":"reasoning_effort is unsupported; response_format is not supported"}}"#
        let requests = try run(responses: [(400, body), (200, success)])
        XCTAssertEqual(requests.count, 2)
        XCTAssertNil(try payload(requests[1])["reasoning_effort"])
        XCTAssertNil(try payload(requests[1])["response_format"])
    }

    func testBuiltInResponseFormatPolicyIsUnchanged() throws {
        for provider in ["openai", "openrouter"] {
            let requests = try run(
                provider: provider,
                responses: [(400, formatError)],
                expectSuccess: false
            )
            XCTAssertEqual(requests.count, 1)
        }
    }

    private func run(
        provider: String = "tokenguard",
        responses: [(Int, String)],
        expectSuccess: Bool = true
    ) throws -> [URLRequest] {
        var requests: [URLRequest] = []
        CompatibilityURLProtocol.handler = { request in
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
        sessionConfig.protocolClasses = [CompatibilityURLProtocol.self]
        let session = URLSession(configuration: sessionConfig)
        defer { session.invalidateAndCancel() }
        let service = LLMService(session: session)
        let done = expectation(description: "Request completes once")
        done.assertForOverFulfill = true
        service.processText("Original text", config: .init(
            provider: provider,
            apiKey: "key", openRouterApiKey: "router-key",
            customProviderApiKey: "custom-key",
            customProviderBaseUrl: "https://example.test/v1",
            model: "test-model", customPrompt: "Rewrite naturally.",
            context: "Saved context", targetProfileInstruction: "British English",
            screenshotAttachment: .init(mimeType: "image/png", base64Data: "abc"),
            reasoningEffort: .none
        )) { content, variantOrError in
            if expectSuccess {
                XCTAssertEqual(content, "Rewritten text")
                XCTAssertEqual(variantOrError, "Rewritten text")
            } else {
                XCTAssertNil(content)
                XCTAssertNotNil(variantOrError)
            }
            done.fulfill()
        }
        wait(for: [done], timeout: 3)
        return requests
    }

    private func payload(_ request: URLRequest) throws -> [String: Any] {
        let body = try XCTUnwrap(request.httpBody)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
    }
}

private final class CompatibilityURLProtocol: URLProtocol {
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
