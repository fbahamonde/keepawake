import Foundation
import IOKit
import IOKit.pwr_mgt

protocol AssertionExecutor: AnyObject {
    func acquire(reason: String) throws
    func release()
    func isStillHeld() -> Bool
}

final class IOPMAssertionExecutor: AssertionExecutor {
    private var assertionID: IOPMAssertionID = 0
    private var isAcquired = false

    func acquire(reason: String) throws {
        guard !isAcquired else { return }
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertPreventUserIdleSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason as CFString,
            &assertionID
        )
        guard result == kIOReturnSuccess else {
            throw NSError(domain: "KeepAwake", code: Int(result), userInfo: [
                NSLocalizedDescriptionKey: "IOPMAssertionCreateWithName failed: \(result)"
            ])
        }
        isAcquired = true
        Log.assertion.info("Acquired assertion id=\(self.assertionID, privacy: .public)")
    }

    func release() {
        guard isAcquired else { return }
        IOPMAssertionRelease(assertionID)
        Log.assertion.info("Released assertion id=\(self.assertionID, privacy: .public)")
        assertionID = 0
        isAcquired = false
    }

    func isStillHeld() -> Bool {
        guard isAcquired else { return false }
        let props = IOPMAssertionCopyProperties(assertionID)
        return props != nil
    }
}

final class KeepAwakeController {
    private let executor: AssertionExecutor
    private(set) var state: AppState = .off
    private let queue = DispatchQueue(label: "com.felipe.keepawake.controller")

    init(executor: AssertionExecutor) {
        self.executor = executor
    }

    func turnOn(target: String?, currentSSID: String?) throws {
        try queue.sync {
            guard case .off = state else { return }
            try executor.acquire(reason: "User enabled KeepAwake")
            state = .on(targetSSID: target, currentSSID: currentSSID)
            Log.state.info("State: off -> on (target=\(target ?? "nil", privacy: .public))")
        }
    }

    func turnOff() {
        queue.sync {
            if case .off = state { return }
            executor.release()
            state = .off
            Log.state.info("State: * -> off")
        }
    }

    func handleNetworkEvent(_ event: NetworkEvent, target: String?) {
        queue.sync {
            switch event {
            case .matched(let ssid):
                switch state {
                case .paused:
                    do {
                        try executor.acquire(reason: "Network match returned")
                        state = .on(targetSSID: target, currentSSID: ssid)
                    } catch {
                        Log.assertion.error("Failed to reacquire on match: \(error.localizedDescription)")
                    }
                case .on:
                    state = .on(targetSSID: target, currentSSID: ssid)
                case .grace:
                    state = .on(targetSSID: target, currentSSID: ssid)
                case .off:
                    break
                }
            case .graceStarted(let ssid, let deadline):
                if case .on = state, let t = target {
                    state = .grace(targetSSID: t, currentSSID: ssid, deadline: deadline)
                }
            case .paused:
                switch state {
                case .on:
                    if let t = target {
                        executor.release()
                        state = .paused(targetSSID: t)
                    }
                case .grace(let t, _, _):
                    executor.release()
                    state = .paused(targetSSID: t)
                default:
                    break
                }
            case .resumed(let ssid):
                if case .paused = state {
                    do {
                        try executor.acquire(reason: "Network resumed")
                        state = .on(targetSSID: target, currentSSID: ssid)
                    } catch {
                        Log.assertion.error("Failed to reacquire on resume: \(error.localizedDescription)")
                    }
                }
            case .unknown:
                break
            }
        }
    }

    func revalidateAfterWake() {
        queue.sync {
            guard state.isAssertionHeld else { return }
            if !executor.isStillHeld() {
                Log.assertion.info("Assertion was dropped during sleep, reacquiring")
                try? executor.acquire(reason: "Revalidate after wake")
            }
        }
    }
}
