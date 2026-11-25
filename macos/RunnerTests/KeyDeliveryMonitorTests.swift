import XCTest
@testable import Make_It_Sound_Natural

final class KeyDeliveryMonitorTests: XCTestCase {
    private let start = Date(timeIntervalSinceReferenceDate: 0)

    /// Presses `count` keys `interval` seconds apart and returns what each
    /// press decided.
    private func press(
        _ count: Int,
        every interval: TimeInterval,
        from offset: TimeInterval = 0,
        on monitor: inout KeyDeliveryMonitor
    ) -> [Bool] {
        (0..<count).map { index in
            monitor.recordKeyDown(
                at: start.addingTimeInterval(offset + Double(index) * interval)
            )
        }
    }

    func testReportsOnceWhenTypingGoesUnacknowledged() {
        var monitor = KeyDeliveryMonitor()

        let decisions = press(12, every: 0.5, on: &monitor)

        XCTAssertEqual(decisions.filter { $0 }.count, 1)
        XCTAssertEqual(decisions.firstIndex(of: true), 7)
    }

    func testStaysQuietWhileDartAcknowledges() {
        var monitor = KeyDeliveryMonitor()

        let decisions = (0..<40).map { index -> Bool in
            let reported = monitor.recordKeyDown(
                at: start.addingTimeInterval(Double(index) * 0.5)
            )
            if index.isMultiple(of: 2) {
                monitor.recordAcknowledgement()
            }
            return reported
        }

        XCTAssertFalse(decisions.contains(true))
    }

    func testIgnoresBurstWhoseAcknowledgementIsStillOnItsWay() {
        var monitor = KeyDeliveryMonitor()

        let decisions = press(20, every: 0.1, on: &monitor)

        XCTAssertFalse(decisions.contains(true))
    }

    func testIgnoresStrayKeysHoursApart() {
        var monitor = KeyDeliveryMonitor()

        let decisions = press(20, every: 3600, on: &monitor)

        XCTAssertFalse(decisions.contains(true))
    }

    func testReportsAgainOnlyAfterTheReportInterval() {
        var monitor = KeyDeliveryMonitor()
        _ = press(8, every: 0.5, on: &monitor)

        let decisions = press(130, every: 0.5, from: 4, on: &monitor)

        let secondReportAt = 3.5 + KeyDeliveryMonitor.minimumReportInterval
        XCTAssertEqual(decisions.filter { $0 }.count, 1)
        XCTAssertEqual(
            decisions.firstIndex(of: true),
            Int((secondReportAt - 4) / 0.5)
        )
    }

    func testAcknowledgementStartsNewStall() {
        var monitor = KeyDeliveryMonitor()
        _ = press(7, every: 0.5, on: &monitor)
        monitor.recordAcknowledgement()

        let decisions = press(7, every: 0.5, from: 3.5, on: &monitor)

        XCTAssertFalse(decisions.contains(true))
        XCTAssertEqual(monitor.unacknowledgedCount, 7)
    }
}
