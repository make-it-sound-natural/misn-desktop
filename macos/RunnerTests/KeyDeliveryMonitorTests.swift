import XCTest
@testable import Make_It_Sound_Natural

final class KeyDeliveryMonitorTests: XCTestCase {
    private typealias Stall = KeyDeliveryMonitor.Stall

    private let start = Date(timeIntervalSinceReferenceDate: 0)

    private func time(_ offset: TimeInterval) -> Date {
        start.addingTimeInterval(offset)
    }

    /// Presses `count` keys `interval` seconds apart and returns the stall
    /// each press reported, if any.
    @discardableResult
    private func press(
        _ count: Int,
        every interval: TimeInterval,
        from offset: TimeInterval = 0,
        on monitor: inout KeyDeliveryMonitor
    ) -> [Stall?] {
        (0..<count).map { index in
            let now = time(offset + Double(index) * interval)
            monitor.recordKeyDown(at: now)
            return monitor.takeStall(at: now)
        }
    }

    func testReportsOnceWhenTypingGoesUnacknowledged() {
        var monitor = KeyDeliveryMonitor()

        let stalls = press(12, every: 0.5, on: &monitor)

        XCTAssertEqual(stalls.compactMap { $0 }.count, 1)
        XCTAssertEqual(stalls[7], Stall(keyPresses: 8, duration: 3.5))
    }

    func testStaysQuietWhileDartAcknowledges() {
        var monitor = KeyDeliveryMonitor()

        let stalls = (0..<40).map { index -> Stall? in
            let now = time(Double(index) * 0.5)
            monitor.recordKeyDown(at: now)
            let stall = monitor.takeStall(at: now)
            if index.isMultiple(of: 2) {
                monitor.recordAcknowledgement()
            }
            return stall
        }

        XCTAssertEqual(stalls.compactMap { $0 }, [])
    }

    func testReportsWordTypedInOneBurstAtTheDeadline() {
        var monitor = KeyDeliveryMonitor()

        let stalls = press(8, every: 0.1, on: &monitor)

        XCTAssertEqual(stalls.compactMap { $0 }, [])
        XCTAssertEqual(monitor.stallDeadline, time(3))
        XCTAssertEqual(
            monitor.takeStall(at: time(3)),
            Stall(keyPresses: 8, duration: 3)
        )
    }

    func testAcknowledgementBeforeTheDeadlineCancelsTheStall() {
        var monitor = KeyDeliveryMonitor()
        press(8, every: 0.1, on: &monitor)

        monitor.recordAcknowledgement()

        XCTAssertNil(monitor.stallDeadline)
        XCTAssertNil(monitor.takeStall(at: time(3)))
    }

    func testFewKeyPressesAreNotAStall() {
        var monitor = KeyDeliveryMonitor()

        press(7, every: 0.1, on: &monitor)

        XCTAssertNil(monitor.stallDeadline)
        XCTAssertNil(monitor.takeStall(at: time(3)))
    }

    func testIgnoresStrayKeysHoursApart() {
        var monitor = KeyDeliveryMonitor()

        let stalls = press(20, every: 3600, on: &monitor)

        XCTAssertEqual(stalls.compactMap { $0 }, [])
    }

    func testReportsAgainOnlyAfterTheReportInterval() {
        var monitor = KeyDeliveryMonitor()
        press(8, every: 0.5, on: &monitor)

        let stalls = press(130, every: 0.5, from: 4, on: &monitor)

        let secondReportAt = 3.5 + KeyDeliveryMonitor.minimumReportInterval
        XCTAssertEqual(stalls.compactMap { $0 }.count, 1)
        XCTAssertEqual(
            stalls.firstIndex { $0 != nil },
            Int((secondReportAt - 4) / 0.5)
        )
    }

    func testReportIntervalOutlivesTheReportedStall() {
        var monitor = KeyDeliveryMonitor()
        press(8, every: 0.5, on: &monitor)

        monitor.recordAcknowledgement()
        let afterAcknowledgement = press(8, every: 0.5, from: 4, on: &monitor)
        let afterPause = press(8, every: 0.5, from: 30, on: &monitor)

        XCTAssertEqual(afterAcknowledgement.compactMap { $0 }, [])
        XCTAssertEqual(afterPause.compactMap { $0 }, [])
    }

    func testAcknowledgementStartsNewStall() {
        var monitor = KeyDeliveryMonitor()
        press(7, every: 0.5, on: &monitor)
        monitor.recordAcknowledgement()

        let stalls = press(7, every: 0.5, from: 3.5, on: &monitor)

        XCTAssertEqual(stalls.compactMap { $0 }, [])
        XCTAssertNil(monitor.stallDeadline)
    }
}
