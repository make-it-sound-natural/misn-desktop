import XCTest
@testable import Make_It_Sound_Natural

final class LLMServiceAuthFailureTests: XCTestCase {
    override func setUp() {
        super.setUp()
        URLProtocol.registerClass(AuthFailureURLProtocol.self)
    }

    override func tearDown() {
        URLProtocol.unregisterClass(AuthFailureURLProtocol.self)
        AuthFailureURLProtocol.responseBody = nil
        super.tearDown()
    }

    func testProcessTextForwardsAuthFailureWithProvider() {
        AuthFailureURLProtocol.responseBody = """
        {"error":{"code":"invalid_api_key"}}
        """.data(using: .utf8)
        let service = LLMService()
        let delegate = CapturingLLMDelegate()
        service.delegate = delegate
        let expectation = expectation(description: "LLM request completes")

        service.processText("Hello", config: .init(
            provider: AppDefaults.openRouterProvider,
            apiKey: "openai-key",
            openRouterApiKey: "bad-openrouter-key",
            customProviderApiKey: "",
            customProviderBaseUrl: nil,
            model: AppDefaults.model,
            customPrompt: nil,
            context: nil,
            targetProfileInstruction: "Rewrite naturally.",
            screenshotAttachment: nil
        )) { _, error in
            XCTAssertEqual(error, "Invalid API key. Check settings.")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2)
        XCTAssertEqual(delegate.error, "Invalid API key. Check settings.")
        XCTAssertEqual(delegate.provider, AppDefaults.openRouterProvider)
        XCTAssertTrue(delegate.isAuthenticationFailure)
    }
}

private final class CapturingLLMDelegate: LLMServiceDelegate {
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

private final class AuthFailureURLProtocol: URLProtocol {
    static var responseBody: Data?

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(
        for request: URLRequest
    ) -> URLRequest {
        request
    }

    override func startLoading() {
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 401,
            httpVersion: nil,
            headerFields: nil
        )!
        client?.urlProtocol(
            self,
            didReceive: response,
            cacheStoragePolicy: .notAllowed
        )
        client?.urlProtocol(self, didLoad: Self.responseBody ?? Data())
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
