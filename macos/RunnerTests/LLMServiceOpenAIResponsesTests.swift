import XCTest
@testable import Make_It_Sound_Natural

final class LLMServiceOpenAIResponsesTests: XCTestCase {
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
                let first = try jsonBody(outcome.requests[0])
                let second = try jsonBody(outcome.requests[1])
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

    func testRejectedReasoningStaysOffForTheSameModelAndEffort() throws {
        let error = #"{"error":{"param":"reasoning","code":"unsupported_parameter"}}"#
        let transport = ScriptedLLMTransport(responses: [
            (400, error), (200, success), (200, success),
            (200, success), (200, success)
        ])
        defer { transport.invalidate() }
        let service = LLMService(session: transport.session)

        for (model, effort) in [
            ("gpt-4.1", ReasoningEffort.none), ("gpt-4.1", .none),
            ("gpt-6.1-sol", .none), ("gpt-4.1", .low)
        ] {
            let result = processTextAndWait(
                service, config: config(model: model, effort: effort)
            )
            XCTAssertEqual(result.variantOrError, "b")
        }

        XCTAssertEqual(transport.requests.count, 5)
        guard transport.requests.count == 5 else { return }
        let reasoning = try transport.requests.map {
            try jsonBody($0)["reasoning"] as? [String: String]
        }
        XCTAssertEqual(reasoning, [
            ["effort": "none"], nil, nil, ["effort": "none"], ["effort": "low"]
        ])
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
            XCTAssertNil(try jsonBody(outcome.requests[1])["reasoning"])
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
        let tiers: [(RequestSpeed, String)] = [
            (.fast, "fast"), (.ultrafast, "ultrafast")
        ]
        for (speed, tier) in tiers {
            for status in [400, 422] {
                let outcome = run(responses: [(status, error)], speed: speed)
                XCTAssertEqual(outcome.requests.count, 1)
                let request = try XCTUnwrap(outcome.requests.first)
                XCTAssertEqual(
                    try jsonBody(request)["service_tier"] as? String,
                    tier
                )
                XCTAssertNil(outcome.content)
                XCTAssertEqual(outcome.variantOrError, message)
                XCTAssertEqual(outcome.delegate.error, message)
            }
        }
    }

    private struct Outcome {
        let requests: [URLRequest]
        let content: String?
        let variantOrError: String?
        let delegate: CapturingLLMDelegate
    }

    private func run(
        responses: [(Int, String)],
        speed: RequestSpeed = .standard,
        model: String = "gpt-6.1-sol"
    ) -> Outcome {
        let transport = ScriptedLLMTransport(responses: responses)
        defer { transport.invalidate() }
        let service = LLMService(session: transport.session)
        let delegate = CapturingLLMDelegate()
        service.delegate = delegate
        let result = processTextAndWait(
            service, config: config(speed: speed, model: model)
        )
        return Outcome(
            requests: transport.requests, content: result.content,
            variantOrError: result.variantOrError, delegate: delegate
        )
    }

    private func config(
        speed: RequestSpeed = .standard,
        model: String = "gpt-6.1-sol",
        effort: ReasoningEffort = .none
    ) -> LLMService.Configuration {
        .init(
            provider: AppDefaults.openAiProvider,
            apiKey: "openai-key", openRouterApiKey: "", customProviderApiKey: "",
            customProviderBaseUrl: nil, model: model, customPrompt: nil,
            context: nil, targetProfileInstruction: nil, screenshotAttachment: nil,
            accessibilityContext: nil, reasoningEffort: effort,
            requestSpeed: speed
        )
    }
}
