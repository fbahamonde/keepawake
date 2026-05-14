import Foundation
import IOKit
import IOKit.pwr_mgt

protocol AssertionExecutor: AnyObject {
    func acquire(reason: String, includeDisplay: Bool) throws
    func release()
    func isStillHeld() -> Bool
}

final class IOPMAssertionExecutor: AssertionExecutor {
    private var systemID: IOPMAssertionID = 0
    private var displayID: IOPMAssertionID = 0
    private var hasSystem = false
    private var hasDisplay = false

    func acquire(reason: String, includeDisplay: Bool) throws {
        if !hasSystem {
            let r = IOPMAssertionCreateWithName(
                kIOPMAssertPreventUserIdleSystemSleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                reason as CFString,
                &systemID
            )
            guard r == kIOReturnSuccess else {
                throw NSError(domain: "KeepAwake", code: Int(r), userInfo: [
                    NSLocalizedDescriptionKey: "PreventUserIdleSystemSleep failed: \(r)"
                ])
            }
            hasSystem = true
            Log.assertion.info("Acquired system assertion id=\(self.systemID, privacy: .public)")
        }
        if includeDisplay && !hasDisplay {
            let r = IOPMAssertionCreateWithName(
                kIOPMAssertPreventUserIdleDisplaySleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                reason as CFString,
                &displayID
            )
            guard r == kIOReturnSuccess else {
                throw NSError(domain: "KeepAwake", code: Int(r), userInfo: [
                    NSLocalizedDescriptionKey: "PreventUserIdleDisplaySleep failed: \(r)"
                ])
            }
            hasDisplay = true
            Log.assertion.info("Acquired display assertion id=\(self.displayID, privacy: .public)")
        }
        if !includeDisplay && hasDisplay {
            IOPMAssertionRelease(displayID)
            Log.assertion.info("Released display assertion id=\(self.displayID, privacy: .public)")
            displayID = 0
            hasDisplay = false
        }
    }

    func release() {
        if hasSystem {
            IOPMAssertionRelease(systemID)
            Log.assertion.info("Released system assertion id=\(self.systemID, privacy: .public)")
            systemID = 0
            hasSystem = false
        }
        if hasDisplay {
            IOPMAssertionRelease(displayID)
            Log.assertion.info("Released display assertion id=\(self.displayID, privacy: .public)")
            displayID = 0
            hasDisplay = false
        }
    }

    func isStillHeld() -> Bool {
        guard hasSystem else { return false }
        guard let unmanaged = IOPMAssertionCopyProperties(systemID) else { return false }
        let props = unmanaged.takeRetainedValue() as? [String: Any] ?? [:]
        let levelKey = kIOPMAssertionLevelKey as String
        if let level = props[levelKey] as? Int, level == kIOPMAssertionLevelOn {
            return true
        }
        return false
    }
}

/// All methods must be called on the main thread.
final class KeepAwakeController {
    private let executor: AssertionExecutor
    private(set) var state: AppState = .off
    private var includeDisplay = false

    init(executor: AssertionExecutor) {
        self.executor = executor
    }

    func turnOn(target: String?, currentSSID: String?, includeDisplay: Bool = false) throws {
        dispatchPrecondition(condition: .onQueue(.main))
        guard case .off = state else { return }
        self.includeDisplay = includeDisplay
        try executor.acquire(reason: "User enabled KeepAwake", includeDisplay: includeDisplay)
        state = .on(targetSSID: target, currentSSID: currentSSID)
        Log.state.info("State: off -> on (target=\(target ?? "nil", privacy: .private), display=\(includeDisplay, privacy: .public))")
    }

    func turnOff() {
        dispatchPrecondition(condition: .onQueue(.main))
        if case .off = state { return }
        executor.release()
        state = .off
        Log.state.info("State: * -> off")
    }

    /// Update display preference while running. If state is currently active, this re-acquires/releases the display assertion.
    func setIncludeDisplay(_ value: Bool) {
        dispatchPrecondition(condition: .onQueue(.main))
        includeDisplay = value
        if state.isAssertionHeld {
            try? executor.acquire(reason: "Display preference changed", includeDisplay: value)
        }
    }

    func handleNetworkEvent(_ event: NetworkEvent, target: String?) {
        dispatchPrecondition(condition: .onQueue(.main))
        switch event {
        case .matched(let ssid):
            switch state {
            case .paused:
                do {
                    try executor.acquire(reason: "Network match returned", includeDisplay: includeDisplay)
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
                    try executor.acquire(reason: "Network resumed", includeDisplay: includeDisplay)
                    state = .on(targetSSID: target, currentSSID: ssid)
                } catch {
                    Log.assertion.error("Failed to reacquire on resume: \(error.localizedDescription)")
                }
            }
        case .unknown:
            break
        }
    }

    func revalidateAfterWake() {
        dispatchPrecondition(condition: .onQueue(.main))
        guard state.isAssertionHeld else { return }
        if !executor.isStillHeld() {
            Log.assertion.info("Assertion was dropped during sleep, reacquiring")
            try? executor.acquire(reason: "Revalidate after wake", includeDisplay: includeDisplay)
        }
    }
}
