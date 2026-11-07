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

    func testReasoningFallbackForEveryProviderPreservesRequest() throws {
        for provider in ["openrouter", "tokenguard", "custom-endpoint"] {
            let requests = try run(
                provider: provider,
                responses: [(400, reasoningError), (200, success)]
            )
            XCTAssertEqual(requests.count, 2)
            let original = try jsonBody(requests[0])
            var expected = original
            expected.removeValue(forKey: "reasoning_effort")
            XCTAssertEqual(try jsonBody(requests[1]) as NSDictionary, expected as NSDictionary)
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
            let original = try jsonBody(requests[0])
            let intermediate = try jsonBody(requests[1])
            if errors[0] == reasoningError {
                XCTAssertNil(intermediate["reasoning_effort"])
                XCTAssertNotNil(intermediate["response_format"])
            } else {
                XCTAssertNotNil(intermediate["reasoning_effort"])
                XCTAssertNil(intermediate["response_format"])
            }
            let final = try jsonBody(requests[2])
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
        XCTAssertEqual(try jsonBody(requests[1])["reasoning_effort"] as? String, "none")
        XCTAssertNil(try jsonBody(requests[1])["response_format"])
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
            XCTAssertNil(try jsonBody(requests[1])["reasoning_effort"])
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
        XCTAssertNil(try jsonBody(requests[1])["reasoning_effort"])
        XCTAssertNil(try jsonBody(requests[1])["response_format"])
    }

    func testBuiltInResponseFormatPolicyIsUnchanged() throws {
        for provider in ["openrouter"] {
            let requests = try run(
                provider: provider,
                responses: [(400, formatError)],
                expectSuccess: false
            )
            XCTAssertEqual(requests.count, 1)
        }
    }

    func testRejectedParametersStayRemovedForTheSameSettings() throws {
        let requests = runOnOneService([config(), config()], responses: [
            (400, reasoningError), (400, formatError),
            (200, success), (200, success)
        ])

        XCTAssertEqual(requests.count, 4)
        guard requests.count == 4 else { return }
        XCTAssertNotNil(try jsonBody(requests[0])["reasoning_effort"])
        let next = try jsonBody(requests[3])
        XCTAssertNil(next["reasoning_effort"])
        XCTAssertNil(next["response_format"])
        XCTAssertEqual(
            next as NSDictionary, try jsonBody(requests[2]) as NSDictionary
        )
    }

    func testOtherModelEffortOrEndpointStartsWithTheFullRequest() throws {
        let others: [(LLMService.Configuration, String)] = [
            (config(model: "other-model"), "none"),
            (config(reasoningEffort: .low), "low"),
            (config(baseUrl: "https://other.test/v1"), "none"),
            (config(provider: "custom-endpoint"), "none")
        ]
        let requests = runOnOneService(
            [config()] + others.map(\.0),
            responses: [(400, reasoningError)] +
                Array(repeating: (200, success), count: 1 + others.count)
        )

        XCTAssertEqual(requests.count, 2 + others.count)
        guard requests.count == 2 + others.count else { return }
        for (index, (_, effort)) in others.enumerated() {
            XCTAssertEqual(
                try jsonBody(requests[2 + index])["reasoning_effort"] as? String,
                effort,
                "\(index)"
            )
        }
    }

    func testFailedRetryIsNotRemembered() throws {
        let serverError = #"{"error":{"message":"Internal error"}}"#
        let requests = runOnOneService([config(), config()], responses: [
            (400, reasoningError), (500, serverError), (200, success)
        ])

        XCTAssertEqual(requests.count, 3)
        guard requests.count == 3 else { return }
        XCTAssertEqual(
            try jsonBody(requests[2])["reasoning_effort"] as? String, "none"
        )
    }

    func testUnparsableSuccessBodyCompletesWithParserMessage() throws {
        _ = try run(
            responses: [(200, #"{"choices":[]}"#)],
            expectSuccess: false,
            expectedError: "Invalid JSON structure"
        )
        _ = try run(
            responses: [(200, "not JSON")],
            expectSuccess: false,
            expectedError: "JSON parsing error"
        )
    }

    func testNetworkFailureCompletesWithItsMessage() {
        let sessionConfig = URLSessionConfiguration.ephemeral
        sessionConfig.protocolClasses = [TimedOutURLProtocol.self]
        let session = URLSession(configuration: sessionConfig)
        defer { session.invalidateAndCancel() }
        let service = LLMService(session: session)
        let done = expectation(description: "Request completes once")
        service.processText("Original text", config: .init(
            provider: "tokenguard",
            apiKey: "", openRouterApiKey: "",
            customProviderApiKey: "custom-key",
            customProviderBaseUrl: "https://example.test/v1",
            model: "test-model", customPrompt: nil, context: nil,
            targetProfileInstruction: nil, screenshotAttachment: nil,
            accessibilityContext: nil
        )) { content, error in
            XCTAssertNil(content)
            XCTAssertEqual(
                error,
                "Network error: \(URLError(.timedOut).localizedDescription)"
            )
            done.fulfill()
        }
        wait(for: [done], timeout: 3)
    }

    private func run(
        provider: String = "tokenguard",
        responses: [(Int, String)],
        expectSuccess: Bool = true,
        expectedError: String? = nil
    ) throws -> [URLRequest] {
        let transport = ScriptedLLMTransport(responses: responses)
        defer { transport.invalidate() }
        let service = LLMService(session: transport.session)
        let result = processTextAndWait(
            service, config: config(provider: provider)
        )
        if expectSuccess {
            XCTAssertEqual(result.content, "Rewritten text")
            XCTAssertEqual(result.variantOrError, "Rewritten text")
        } else {
            XCTAssertNil(result.content)
            XCTAssertNotNil(result.variantOrError)
            if let expectedError {
                XCTAssertEqual(result.variantOrError, expectedError)
            }
        }
        return transport.requests
    }

    /// Sends one rewrite per configuration through the same service.
    private func runOnOneService(
        _ configs: [LLMService.Configuration],
        responses: [(Int, String)]
    ) -> [URLRequest] {
        let transport = ScriptedLLMTransport(responses: responses)
        defer { transport.invalidate() }
        let service = LLMService(session: transport.session)
        for config in configs {
            _ = processTextAndWait(service, config: config)
        }
        return transport.requests
    }

    private func config(
        provider: String = "tokenguard",
        baseUrl: String = "https://example.test/v1",
        model: String = "test-model",
        reasoningEffort: ReasoningEffort = .none
    ) -> LLMService.Configuration {
        .init(
            provider: provider,
            apiKey: "key", openRouterApiKey: "router-key",
            customProviderApiKey: "custom-key",
            customProviderBaseUrl: baseUrl,
            model: model, customPrompt: "Rewrite naturally.",
            context: "Saved context", targetProfileInstruction: "British English",
            screenshotAttachment: .init(mimeType: "image/png", base64Data: "abc"),
            accessibilityContext: nil,
            reasoningEffort: reasoningEffort
        )
    }
}

private final class TimedOutURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        client?.urlProtocol(self, didFailWithError: URLError(.timedOut))
    }

    override func stopLoading() {}
}
