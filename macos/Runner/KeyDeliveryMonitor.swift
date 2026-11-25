import Foundation

/// Decides when key presses have stopped reaching the Dart side.
///
/// AppKit hands every key-down to the app before Flutter sees it, and Dart
/// acknowledges the ones it received a moment later. A run of key-downs with
/// no acknowledgement means they were lost on the way: the engine's key queue
/// is wedged, or another window took them.
struct KeyDeliveryMonitor {
    /// Fewer presses than this is a stray key, not someone typing.
    static let unacknowledgedLimit = 8
    /// Dart acknowledges within a fraction of a second, so a few seconds of
    /// silence rules out an acknowledgement that is merely on its way.
    static let minimumStallDuration: TimeInterval = 3
    /// Someone who cannot type keeps pressing keys; one report is enough.
    static let minimumReportInterval: TimeInterval = 60
    /// Presses further apart than this are separate attempts. Without it,
    /// stray keys from hours ago would add up to a stall that never happened.
    static let maximumGapBetweenKeyDowns: TimeInterval = 10

    private(set) var unacknowledgedCount = 0
    private var firstUnacknowledgedAt: Date?
    private var lastKeyDownAt: Date?
    private var lastReportedAt: Date?

    /// Seconds since the oldest key-down Dart has not acknowledged.
    func stallDuration(at now: Date) -> TimeInterval {
        firstUnacknowledgedAt.map { now.timeIntervalSince($0) } ?? 0
    }

    /// Records a key-down and tells whether the stall should be reported now.
    mutating func recordKeyDown(at now: Date) -> Bool {
        if let lastKeyDownAt,
           now.timeIntervalSince(lastKeyDownAt) > Self.maximumGapBetweenKeyDowns {
            startNewStall()
        }
        lastKeyDownAt = now
        unacknowledgedCount += 1
        if firstUnacknowledgedAt == nil {
            firstUnacknowledgedAt = now
        }

        guard unacknowledgedCount >= Self.unacknowledgedLimit,
              stallDuration(at: now) >= Self.minimumStallDuration else {
            return false
        }
        if let lastReportedAt,
           now.timeIntervalSince(lastReportedAt) < Self.minimumReportInterval {
            return false
        }
        lastReportedAt = now
        return true
    }

    /// Records that Dart received every key-down sent so far.
    mutating func recordAcknowledgement() {
        startNewStall()
    }

    private mutating func startNewStall() {
        unacknowledgedCount = 0
        firstUnacknowledgedAt = nil
    }
}
