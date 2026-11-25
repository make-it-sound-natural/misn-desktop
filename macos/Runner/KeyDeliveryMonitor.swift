import Foundation

/// Decides when key presses have stopped reaching the Dart side.
///
/// AppKit hands every key-down to the app before Flutter sees it, and Dart
/// acknowledges the ones it received a moment later. A run of key-downs with
/// no acknowledgement means they were lost on the way: the engine's key queue
/// is wedged, or another window took them.
struct KeyDeliveryMonitor {
    /// A run of key-downs Dart never acknowledged.
    struct Stall: Equatable {
        let keyPresses: Int
        let duration: TimeInterval
    }

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

    private var unacknowledgedCount = 0
    private var firstUnacknowledgedAt: Date?
    private var lastKeyDownAt: Date?
    private var lastReportedAt: Date?

    /// When the key-downs so far count as lost, unless Dart acknowledges
    /// them first.
    ///
    /// The person may stop typing before this moment, so the caller has to
    /// ask for the stall then instead of waiting for the next key-down.
    var stallDeadline: Date? {
        guard unacknowledgedCount >= Self.unacknowledgedLimit else {
            return nil
        }
        return firstUnacknowledgedAt?
            .addingTimeInterval(Self.minimumStallDuration)
    }

    mutating func recordKeyDown(at now: Date) {
        if let lastKeyDownAt,
           now.timeIntervalSince(lastKeyDownAt) > Self.maximumGapBetweenKeyDowns {
            startNewStall()
        }
        lastKeyDownAt = now
        unacknowledgedCount += 1
        if firstUnacknowledgedAt == nil {
            firstUnacknowledgedAt = now
        }
    }

    /// Records that Dart received every key-down sent so far.
    mutating func recordAcknowledgement() {
        startNewStall()
    }

    /// Returns the stall to report at `now` and marks it reported.
    ///
    /// The report interval outlives the stall: a second stall soon after a
    /// reported one stays quiet.
    mutating func takeStall(at now: Date) -> Stall? {
        guard let stallDeadline, now >= stallDeadline,
              let firstUnacknowledgedAt else {
            return nil
        }
        if let lastReportedAt,
           now.timeIntervalSince(lastReportedAt) < Self.minimumReportInterval {
            return nil
        }
        lastReportedAt = now
        return Stall(
            keyPresses: unacknowledgedCount,
            duration: now.timeIntervalSince(firstUnacknowledgedAt)
        )
    }

    private mutating func startNewStall() {
        unacknowledgedCount = 0
        firstUnacknowledgedAt = nil
    }
}
