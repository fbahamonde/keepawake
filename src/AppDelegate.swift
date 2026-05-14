import AppKit
import CoreWLAN
import ServiceManagement
import UserNotifications
import IOKit
import IOKit.pwr_mgt

final class AppDelegate: NSObject, NSApplicationDelegate, CWEventDelegate {
    private let prefs = Preferences()
    private let executor = IOPMAssertionExecutor()
    private var controller: KeepAwakeController!
    private var monitor: NetworkMonitor!
    private var duration: DurationManager!
    private let location = LocationPermissionHelper()
    private let statusItem = StatusItemController()
    private let menuBuilder = MenuBuilder()

    private var sanityTimer: Timer?
    private var wifiClient: CWWiFiClient!
    private var lidMonitor: LidStateMonitor?

    func applicationDidFinishLaunching(_ notification: Notification) {
        SingleInstanceGuard.enforceOrExit()
        Log.lifecycle.info("Launched")

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let e = error { Log.lifecycle.error("Notif auth error: \(e.localizedDescription)") }
            Log.lifecycle.info("Notif auth granted=\(granted)")
        }

        controller = KeepAwakeController(executor: executor)

        monitor = NetworkMonitor(
            ssidProvider: CoreWLANSSIDProvider(),
            onEvent: { [weak self] event in
                DispatchQueue.main.async { self?.handleNetworkEvent(event) }
            }
        )
        monitor.setTarget(prefs.targetSSID)

        duration = DurationManager(onExpired: { [weak self] in
            DispatchQueue.main.async { self?.handleDurationExpired() }
        })

        lidMonitor = LidStateMonitor(onLidClosed: { [weak self] in
            guard let s = self, s.prefs.duration == .untilLidClose else { return }
            s.handleDurationExpired()
        })
        lidMonitor?.start()

        wifiClient = CWWiFiClient.shared()
        try? wifiClient.startMonitoringEvent(with: .ssidDidChange)
        wifiClient.delegate = self

        sanityTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.monitor.tick()
            self?.duration.check()
            self?.controller.revalidateAfterWake()
            self?.refreshUI()
        }

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )

        statusItem.onClick(
            left: { [weak self] in self?.toggleKeepAwake() },
            right: { [weak self] in self?.rebuildMenu() }
        )
        rebuildMenu()

        monitor.tick()
        refreshUI()
    }

    func ssidDidChangeForWiFiInterface(withName interfaceName: String) {
        Log.network.info("SSID changed on \(interfaceName, privacy: .public)")
        DispatchQueue.main.async { [weak self] in
            self?.monitor.tick()
            self?.refreshUI()
        }
    }

    @objc private func handleWake() {
        Log.lifecycle.info("System woke")
        controller.revalidateAfterWake()
        monitor.tick()
        duration.check()
        refreshUI()
    }

    private func toggleKeepAwake() {
        switch controller.state {
        case .off:
            location.requestIfNeeded { [weak self] _ in
                DispatchQueue.main.async { self?.startKeepAwake() }
            }
        default:
            stopKeepAwake()
        }
    }

    private func startKeepAwake() {
        let currentSSID = CoreWLANSSIDProvider().currentSSID()
        do {
            try controller.turnOn(target: prefs.targetSSID, currentSSID: currentSSID)
            duration.start(duration: prefs.duration)
            monitor.tick()
            refreshUI()
            rebuildMenu()
        } catch {
            alert("Could not enable KeepAwake", message: error.localizedDescription)
        }
    }

    private func stopKeepAwake() {
        controller.turnOff()
        duration.stop()
        refreshUI()
        rebuildMenu()
    }

    private func handleNetworkEvent(_ event: NetworkEvent) {
        controller.handleNetworkEvent(event, target: prefs.targetSSID)
        refreshUI()
    }

    private func handleDurationExpired() {
        controller.turnOff()
        notify(title: "KeepAwake session ended", body: "System will sleep normally now.")
        refreshUI()
        rebuildMenu()
    }

    private func refreshUI() {
        let graceRemaining: TimeInterval?
        if case .grace(_, _, let deadline) = controller.state {
            graceRemaining = max(0, deadline.timeIntervalSinceNow)
        } else {
            graceRemaining = nil
        }
        statusItem.update(for: controller.state, graceRemaining: graceRemaining)
    }

    private func rebuildMenu() {
        let currentSSID = CoreWLANSSIDProvider().currentSSID()
        let callbacks = MenuBuilder.Callbacks(
            toggleKeepAwake: { [weak self] in self?.toggleKeepAwake() },
            setDuration: { [weak self] d in
                guard let s = self else { return }
                s.prefs.duration = d
                if s.controller.state.isAssertionHeld {
                    s.duration.start(duration: d)
                }
                s.rebuildMenu()
            },
            setTargetCurrent: { [weak self] in
                guard let s = self, let cur = CoreWLANSSIDProvider().currentSSID() else { return }
                s.prefs.targetSSID = cur
                s.monitor.setTarget(cur)
                s.rebuildMenu()
            },
            clearTarget: { [weak self] in
                self?.prefs.targetSSID = nil
                self?.monitor.setTarget(nil)
                self?.rebuildMenu()
            },
            toggleLaunchAtLogin: { [weak self] in self?.toggleLaunchAtLogin() },
            openPreferences: { [weak self] in self?.openPreferences() },
            showAbout: {
                NSApp.orderFrontStandardAboutPanel(nil)
                NSApp.activate(ignoringOtherApps: true)
            },
            openLocationSettings: { LocationPermissionHelper.openSystemSettings() },
            quit: { NSApp.terminate(nil) }
        )
        let menu = menuBuilder.build(
            state: controller.state,
            target: prefs.targetSSID,
            currentSSID: currentSSID,
            duration: prefs.duration,
            launchAtLogin: prefs.launchAtLogin,
            locationAuthorized: location.isAuthorized,
            callbacks: callbacks
        )
        statusItem.setMenu(menu)
    }

    private func toggleLaunchAtLogin() {
        let service = SMAppService.mainApp
        do {
            if prefs.launchAtLogin {
                try service.unregister()
                prefs.launchAtLogin = false
            } else {
                try service.register()
                prefs.launchAtLogin = true
            }
            rebuildMenu()
        } catch {
            alert("Launch at Login failed", message: error.localizedDescription)
        }
    }

    private func openPreferences() {
        let alert = NSAlert()
        alert.messageText = "Preferences"
        alert.informativeText = """
        Target Wi-Fi: \(prefs.targetSSID ?? "(none)")
        Duration: \(prefs.duration.label)
        Launch at Login: \(prefs.launchAtLogin ? "Yes" : "No")

        Use the menubar menu to change these settings.
        """
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func alert(_ title: String, message: String) {
        let a = NSAlert()
        a.messageText = title
        a.informativeText = message
        a.alertStyle = .warning
        a.runModal()
    }

    private func notify(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req)
    }
}
