import AppKit

enum SingleInstanceGuard {
    static let bundleID = "com.felipe.keepawake"

    static func enforceOrExit() {
        let myPid = ProcessInfo.processInfo.processIdentifier
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .filter { $0.processIdentifier != myPid }
        if let existing = others.first {
            Log.lifecycle.info("Another instance running (pid=\(existing.processIdentifier)), exiting")
            existing.activate()
            exit(0)
        }
    }
}
