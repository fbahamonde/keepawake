import XCTest
@testable import KeepAwakeCore

final class MockClock: Clock {
    var current: Date
    init(start: Date) { self.current = start }
    func now() -> Date { current }
    func advance(by seconds: TimeInterval) { current = current.addingTimeInterval(seconds) }
}

final class DurationManagerTests: XCTestCase {
    var clock: MockClock!
    var manager: DurationManager!
    var expiredFlag: Bool!

    override func setUp() {
        super.setUp()
        clock = MockClock(start: Date(timeIntervalSince1970: 1_700_000_000))
        expiredFlag = false
        manager = DurationManager(clock: clock, onExpired: { [weak self] in self?.expiredFlag = true })
    }

    func testIndefiniteHasNoDeadline() {
        manager.start(duration: .indefinite)
        XCTAssertNil(manager.deadline)
    }

    func testFiniteDurationSetsDeadline() {
        manager.start(duration: .fifteenMin)
        XCTAssertEqual(manager.deadline, clock.current.addingTimeInterval(15 * 60))
    }

    func testCheckBeforeDeadlineNoOp() {
        manager.start(duration: .fifteenMin)
        clock.advance(by: 14 * 60)
        manager.check()
        XCTAssertFalse(expiredFlag)
    }

    func testCheckAfterDeadlineFiresOnExpired() {
        manager.start(duration: .fifteenMin)
        clock.advance(by: 16 * 60)
        manager.check()
        XCTAssertTrue(expiredFlag)
    }

    func testStopCancelsDeadline() {
        manager.start(duration: .fifteenMin)
        manager.stop()
        XCTAssertNil(manager.deadline)
    }

    func testCheckOnlyFiresOnce() {
        manager.start(duration: .fifteenMin)
        clock.advance(by: 16 * 60)
        manager.check()
        expiredFlag = false
        manager.check()
        XCTAssertFalse(expiredFlag)
    }

    func testRemainingSeconds() {
        manager.start(duration: .fifteenMin)
        clock.advance(by: 5 * 60)
        XCTAssertEqual(manager.remainingSeconds ?? -1, 10 * 60, accuracy: 1)
    }

    func testUntilLidCloseHasNoDeadline() {
        manager.start(duration: .untilLidClose)
        XCTAssertNil(manager.deadline)
    }

    func testRestartAfterExpirationCanFireAgain() {
        manager.start(duration: .fifteenMin)
        clock.advance(by: 16 * 60)
        manager.check()
        XCTAssertTrue(expiredFlag)
        expiredFlag = false
        manager.start(duration: .fifteenMin)
        clock.advance(by: 16 * 60)
        manager.check()
        XCTAssertTrue(expiredFlag)
    }
}
