import XCTest
@testable import KeepAwakeCore

final class MockAssertionExecutor: AssertionExecutor {
    var isHeld = false
    var acquireCallCount = 0
    var releaseCallCount = 0
    var shouldFailAcquire = false
    var lastIncludeDisplay = false

    func acquire(reason: String, includeDisplay: Bool) throws {
        if shouldFailAcquire { throw NSError(domain: "test", code: 1) }
        isHeld = true
        acquireCallCount += 1
        lastIncludeDisplay = includeDisplay
    }

    func release() {
        isHeld = false
        releaseCallCount += 1
    }

    func isStillHeld() -> Bool { isHeld }
}

final class KeepAwakeControllerTests: XCTestCase {
    var executor: MockAssertionExecutor!
    var controller: KeepAwakeController!

    override func setUp() {
        super.setUp()
        executor = MockAssertionExecutor()
        controller = KeepAwakeController(executor: executor)
    }

    func testInitialStateIsOff() {
        XCTAssertEqual(controller.state, .off)
    }

    func testTurnOnAcquiresAssertion() throws {
        try controller.turnOn(target: nil, currentSSID: "Net")
        XCTAssertTrue(executor.isHeld)
        XCTAssertEqual(executor.acquireCallCount, 1)
    }

    func testTurnOffReleasesAssertion() throws {
        try controller.turnOn(target: nil, currentSSID: "Net")
        controller.turnOff()
        XCTAssertFalse(executor.isHeld)
        XCTAssertEqual(controller.state, .off)
    }

    func testHandleNetworkPausedReleasesAssertion() throws {
        try controller.turnOn(target: "Home", currentSSID: "Home")
        controller.handleNetworkEvent(.paused, target: "Home")
        XCTAssertFalse(executor.isHeld)
        if case .paused(let t) = controller.state {
            XCTAssertEqual(t, "Home")
        } else {
            XCTFail("expected paused state")
        }
    }

    func testHandleNetworkResumedReacquiresAssertion() throws {
        try controller.turnOn(target: "Home", currentSSID: "Home")
        controller.handleNetworkEvent(.paused, target: "Home")
        XCTAssertFalse(executor.isHeld)
        controller.handleNetworkEvent(.resumed(ssid: "Home"), target: "Home")
        XCTAssertTrue(executor.isHeld)
    }

    func testHandleNetworkGraceKeepsAssertionHeld() throws {
        try controller.turnOn(target: "Home", currentSSID: "Home")
        let deadline = Date().addingTimeInterval(60)
        controller.handleNetworkEvent(.graceStarted(ssid: "Cafe", deadline: deadline), target: "Home")
        XCTAssertTrue(executor.isHeld)
        if case .grace = controller.state {} else { XCTFail("expected grace state") }
    }

    func testTurnOnWhileAlreadyOnIsNoOp() throws {
        try controller.turnOn(target: nil, currentSSID: "X")
        try controller.turnOn(target: nil, currentSSID: "Y")
        XCTAssertEqual(executor.acquireCallCount, 1)
    }

    func testTurnOffWhileAlreadyOffIsNoOp() {
        controller.turnOff()
        XCTAssertEqual(executor.releaseCallCount, 0)
    }

    func testRevalidateReacquiresIfDroppedWhileOn() throws {
        try controller.turnOn(target: nil, currentSSID: "X")
        executor.isHeld = false
        controller.revalidateAfterWake()
        XCTAssertTrue(executor.isHeld)
    }

    func testRevalidateDoesNotAcquireWhenOff() {
        controller.revalidateAfterWake()
        XCTAssertFalse(executor.isHeld)
    }

    func testAcquireFailureKeepsStateOff() {
        executor.shouldFailAcquire = true
        XCTAssertThrowsError(try controller.turnOn(target: nil, currentSSID: nil))
        XCTAssertEqual(controller.state, .off)
    }

    func testTurnOnDefaultsToSystemOnlyAssertion() throws {
        try controller.turnOn(target: nil, currentSSID: nil)
        XCTAssertFalse(executor.lastIncludeDisplay)
    }

    func testTurnOnWithDisplayPassesFlagToExecutor() throws {
        try controller.turnOn(target: nil, currentSSID: nil, includeDisplay: true)
        XCTAssertTrue(executor.lastIncludeDisplay)
    }

    func testSetIncludeDisplayUpdatesExecutorWhenRunning() throws {
        try controller.turnOn(target: nil, currentSSID: nil, includeDisplay: false)
        XCTAssertFalse(executor.lastIncludeDisplay)
        controller.setIncludeDisplay(true)
        XCTAssertTrue(executor.lastIncludeDisplay)
    }

    func testSetIncludeDisplayNoOpWhenOff() {
        controller.setIncludeDisplay(true)
        XCTAssertEqual(executor.acquireCallCount, 0)
    }

    func testResumeUsesStoredIncludeDisplay() throws {
        try controller.turnOn(target: "Home", currentSSID: "Home", includeDisplay: true)
        controller.handleNetworkEvent(.paused, target: "Home")
        executor.lastIncludeDisplay = false
        controller.handleNetworkEvent(.resumed(ssid: "Home"), target: "Home")
        XCTAssertTrue(executor.lastIncludeDisplay)
    }
}
