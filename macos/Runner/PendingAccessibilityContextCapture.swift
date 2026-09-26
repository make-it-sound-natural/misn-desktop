import Foundation

/// An Accessibility read running on a background queue while the shortcut
/// copies the selection. The shortcut waits for it only until a deadline, so
/// a slow or hung app delays the rewrite by at most that much.
final class PendingAccessibilityContextCapture {
    private let request: AccessibilityContextRequest
    private let startedAt: TimeInterval
    private let now: () -> TimeInterval
    private let lock = NSLock()
    private var capture: AccessibilityContextCapture?
    /// Set while `result` waits; taken under the lock by whichever of the
    /// capture and the deadline comes first, so it runs exactly once.
    private var waiter: ((AccessibilityContextCapture?) -> Void)?

    init(
        request: AccessibilityContextRequest,
        capturer: AccessibilityContextCapturing,
        queue: DispatchQueue,
        now: @escaping () -> TimeInterval = {
            ProcessInfo.processInfo.systemUptime
        }
    ) {
        self.request = request
        self.now = now
        self.startedAt = now()
        queue.async { [self] in
            finish(with: capturer.capture(request))
        }
    }

    /// Resolves the read against the copied text. A read still running when
    /// `deadline` seconds have passed since it started counts as a timeout;
    /// its late result is dropped.
    func result(
        copiedText: String,
        deadline: TimeInterval
    ) async -> AccessibilityContextResult {
        let remaining = max(0, deadline - (now() - startedAt))
        let capture = await withCheckedContinuation { continuation in
            wait(timeout: remaining) { continuation.resume(returning: $0) }
        }
        guard let capture = capture else {
            var partial = AccessibilityContext(
                mode: request.mode,
                appName: request.appName,
                bundleId: request.bundleId
            )
            partial.timings.total = (now() - startedAt) * 1_000
            return .unusable(.timeout, partial: partial)
        }
        return capture.resolve(copiedText: copiedText)
    }

    private func wait(
        timeout: TimeInterval,
        completion: @escaping (AccessibilityContextCapture?) -> Void
    ) {
        lock.lock()
        if let capture = capture {
            lock.unlock()
            completion(capture)
            return
        }
        waiter = completion
        lock.unlock()

        DispatchQueue.global(qos: .userInitiated).asyncAfter(
            deadline: .now() + timeout
        ) { [self] in
            takeWaiter()?(nil)
        }
    }

    private func finish(with capture: AccessibilityContextCapture) {
        lock.lock()
        self.capture = capture
        let waiter = self.waiter
        self.waiter = nil
        lock.unlock()
        waiter?(capture)
    }

    private func takeWaiter() -> ((AccessibilityContextCapture?) -> Void)? {
        lock.lock()
        defer { lock.unlock() }
        let waiter = self.waiter
        self.waiter = nil
        return waiter
    }
}
