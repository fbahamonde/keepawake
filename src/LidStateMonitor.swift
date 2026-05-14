import Foundation
import IOKit

// kIOMessageServicePropertyChange = iokit_common_msg(0x130) = sys_iokit | sub_iokit_common | 0x130
// = 0xE0000000 | 0x00000000 | 0x130 = 0xE0000130. The macro isn't bridged into Swift.
private let kIOMessageServicePropertyChangeValue: UInt32 = 0xE0000130

final class LidStateMonitor {
    private var notificationPort: IONotificationPortRef?
    private var notification: io_object_t = 0
    private let onLidClosed: () -> Void

    init(onLidClosed: @escaping () -> Void) {
        self.onLidClosed = onLidClosed
    }

    func start() {
        notificationPort = IONotificationPortCreate(kIOMainPortDefault)
        guard let port = notificationPort else {
            Log.lifecycle.info("IONotificationPortCreate failed; lid-close detection disabled")
            return
        }
        IONotificationPortSetDispatchQueue(port, .main)

        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleClamshellState"))
        guard service != 0 else {
            Log.lifecycle.info("AppleClamshellState service not found; lid-close detection disabled")
            return
        }

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        IOServiceAddInterestNotification(
            port,
            service,
            kIOGeneralInterest,
            { (refcon, _, messageType, _) in
                guard let refcon = refcon else { return }
                let monitor = Unmanaged<LidStateMonitor>.fromOpaque(refcon).takeUnretainedValue()
                if messageType == kIOMessageServicePropertyChangeValue {
                    monitor.checkClamshellState()
                }
            },
            selfPtr,
            &notification
        )
        IOObjectRelease(service)
    }

    func stop() {
        if notification != 0 { IOObjectRelease(notification); notification = 0 }
        if let port = notificationPort { IONotificationPortDestroy(port); notificationPort = nil }
    }

    private func checkClamshellState() {
        let root = IORegistryEntryFromPath(kIOMainPortDefault, "IOService:/IOResources/IOPMrootDomain")
        guard root != 0 else { return }
        defer { IOObjectRelease(root) }

        var props: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(root, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let dict = props?.takeRetainedValue() as? [String: Any] else { return }

        if let closed = dict["AppleClamshellState"] as? Bool, closed {
            Log.lifecycle.info("Lid closed detected")
            onLidClosed()
        }
    }

    deinit { stop() }
}
