import XCTest
@testable import Make_It_Sound_Natural

/// Serves scripted `(status, body)` responses to an `LLMService`, one per
/// request in order, and records each request with its body.
///
/// Only one transport can be active at a time: `ScriptedURLProtocol` routes
/// every request to the transport created last.
final class ScriptedLLMTransport {
    let session: URLSession
    private(set) var requests: [URLRequest] = []
    private let responses: [(Int, String)]

    init(responses: [(Int, String)]) {
        self.responses = responses
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ScriptedURLProtocol.self]
        session = URLSession(configuration: configuration)
        ScriptedURLProtocol.handler = { [weak self] request in
            self?.respond(to: request) ?? (500, "{}")
        }
    }

    /// Cancels the session and detaches the protocol from this transport.
    func invalidate() {
        session.invalidateAndCancel()
        ScriptedURLProtocol.handler = nil
    }

    private func respond(to request: URLRequest) -> (Int, String) {
        requests.append(Self.withBody(request))
        let index = requests.count - 1
        guard index < responses.count else {
            XCTFail("Unexpected extra request")
            return (500, "{}")
        }
        return responses[index]
    }

    /// URLSession hands a protocol the body as a stream, not `httpBody`.
    private static func withBody(_ request: URLRequest) -> URLRequest {
        guard request.httpBody == nil,
              let stream = request.httpBodyStream else { return request }
        var captured = request
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
        return captured
    }
}

/// Answers requests through the handler `ScriptedLLMTransport` installs.
final class ScriptedURLProtocol: URLProtocol {
    static var handler: ((URLRequest) -> (Int, String))?

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(
        for request: URLRequest
    ) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.handler, let url = request.url else { return }
        let (status, body) = handler(request)
        guard let response = HTTPURLResponse(
            url: url, statusCode: status, httpVersion: nil, headerFields: nil
        ) else { return }
        client?.urlProtocol(
            self, didReceive: response, cacheStoragePolicy: .notAllowed
        )
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

/// Records the last failure `LLMService` reported to its delegate.
final class CapturingLLMDelegate: LLMServiceDelegate {
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

/// What `processText` passed to its completion.
struct LLMProcessResult {
    let content: String?
    let variantOrError: String?
}

extension XCTestCase {
    /// Runs `processText` and waits until its completion runs exactly once.
    func processTextAndWait(
        _ service: LLMService,
        text: String = "Original text",
        config: LLMService.Configuration
    ) -> LLMProcessResult {
        var result = LLMProcessResult(content: nil, variantOrError: nil)
        let done = expectation(description: "Request completes once")
        done.assertForOverFulfill = true
        service.processText(text, config: config) { content, variantOrError in
            result = LLMProcessResult(
                content: content, variantOrError: variantOrError
            )
            done.fulfill()
        }
        wait(for: [done], timeout: 3)
        return result
    }

    /// The JSON body of a recorded request.
    func jsonBody(_ request: URLRequest) throws -> [String: Any] {
        let body = try XCTUnwrap(request.httpBody)
        return try XCTUnwrap(
            JSONSerialization.jsonObject(with: body) as? [String: Any]
        )
    }
}
