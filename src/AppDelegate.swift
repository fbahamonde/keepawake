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
                if d.seconds != nil { s.requestNotificationAuthIfNeeded() }
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
            showAbout: {
                let credits = NSMutableAttributedString()
                let base: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 11),
                    .foregroundColor: NSColor.labelColor
                ]
                credits.append(NSAttributedString(string: "Created by Felipe Bahamonde\n", attributes: base))
                credits.append(NSAttributedString(
                    string: "bahamondefelipem@gmail.com\n",
                    attributes: base.merging([.link: URL(string: "mailto:bahamondefelipem@gmail.com")!]) { $1 }
                ))
                credits.append(NSAttributedString(string: "\n", attributes: base))
                credits.append(NSAttributedString(
                    string: "github.com/fbahamonde/keepawake\n",
                    attributes: base.merging([.link: URL(string: "https://github.com/fbahamonde/keepawake")!]) { $1 }
                ))
                credits.append(NSAttributedString(string: "\nMIT License · Personal tool, no warranty.", attributes: base))

                NSApp.orderFrontStandardAboutPanel(options: [
                    .credits: credits,
                    .applicationName: "KeepAwake",
                    .applicationVersion: "1.0.0",
                    NSApplication.AboutPanelOptionKey(rawValue: "Copyright"):
                        "© 2026 Felipe Bahamonde"
                ])
                NSApp.activate(ignoringOtherApps: true)
            },
            showHelp: { [weak self] in self?.showHelp() },
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

    private func showHelp() {
        let englishText = """
        WHAT IT DOES
        Keeps your Mac from sleeping due to inactivity. Useful when leaving an AI agent (Claude Code, Cursor), a long build, a download, or a video call running.

        ⚠️ IMPORTANT LIMITATION
        Does NOT work with the lid closed on battery. Apple Silicon enforces clamshell sleep in firmware below the kernel. No software — not KeepAwake, not caffeinate, not Amphetamine — can bypass it. Useful only with the lid open.

        HOW TO USE
        • Left-click the dog icon 🐕 = toggle on/off
           - Outline dog = off
           - Filled dog = on, your Mac stays awake
        • Right-click = open the menu

        DURATION
        Pick how long the session lasts:
        • 15 min / 1h / 2h / 5h = auto-off when the timer expires
        • Indefinitely = stays on until you turn it off
        • Until lid closes = turns off when you close the lid

        ONLY ON NETWORK (Wi-Fi gating)
        Optional. Stay awake only when connected to a specific Wi-Fi network.
        1. Connect to the Wi-Fi you want (e.g. your phone's hotspot)
        2. Menu → Only on network → "Set current Wi-Fi as target"
        3. If you switch networks → 60s grace period → auto-pauses
        4. Reconnect to the target → re-acquires automatically

        Useful for: an agent that should run only when you have phone internet.
        With no target = works everywhere, no network check.

        ICON STATES
        🐕 outline black    = OFF
        🐕 filled black     = ON, network OK (or no target)
        🐕 filled + orange  = ON, wrong network, 60s countdown
        🐕 outline + gray   = paused, waiting to return to target

        LAUNCH AT LOGIN
        If enabled → the app starts automatically when you log in.

        LOCATION PERMISSION
        macOS classifies the Wi-Fi name (SSID) as sensitive data — it can reveal where you are. Without Location permission, the app cannot read the SSID and Wi-Fi gating is disabled. Basic Keep Awake still works without it.

        RESOURCES
        ~20 MB RAM, 0% CPU when idle. The real battery cost comes from whatever you're running, not KeepAwake.
        """

        let spanishText = """
        QUÉ HACE
        Evita que tu Mac se duerma por inactividad. Útil cuando dejas un agente (Claude Code, Cursor), un build largo, una descarga o una videollamada corriendo.

        ⚠️ LÍMITE IMPORTANTE
        NO funciona con la tapa cerrada en batería. Apple Silicon impone el sleep clamshell en firmware, debajo del kernel. Ningún software —ni KeepAwake, ni caffeinate, ni Amphetamine— puede saltarlo. Sirve solo con la tapa abierta.

        CÓMO USARLA
        • Click izquierdo en el perro 🐕 = encender/apagar
           - Perro vacío (outline) = apagado
           - Perro relleno (filled) = encendido, Mac no duerme
        • Click derecho = abre el menú

        DURATION (cuánto tiempo)
        Elige cuánto rato quieres mantener despierto:
        • 15 min / 1h / 2h / 5h = se apaga solo al expirar
        • Indefinidamente = hasta que tú lo apagues
        • Until lid closes = se apaga al cerrar la tapa

        ONLY ON NETWORK (gating por Wi-Fi)
        Opcional. Solo mantiene despierto si estás en una red Wi-Fi específica.
        1. Conéctate a la red que quieres (ej: hotspot del celular)
        2. Menú → Only on network → "Set current Wi-Fi as target"
        3. Si cambias de red → 60s de gracia → se auto-pausa
        4. Vuelves a la red → se reactiva solo

        Útil para: un agente que solo debería correr si tienes internet del celular.
        Sin target = funciona siempre, sin validar red.

        ESTADOS DEL ICONO
        🐕 outline negro    = OFF
        🐕 filled negro     = ON, red OK (o sin target)
        🐕 filled + naranja = ON, red incorrecta, cuenta regresiva 60s
        🐕 outline + gris   = pausado, esperando volver a la red target

        LAUNCH AT LOGIN
        Si activas → la app arranca sola cuando inicias sesión.

        PERMISO DE UBICACIÓN
        macOS clasifica el nombre de tu red Wi-Fi (SSID) como dato sensible — revela dónde estás. Sin permiso, la app no puede leer el SSID y el gating Wi-Fi queda desactivado. Sin permiso igual funciona el keep-awake básico.

        RECURSOS
        ~20 MB de RAM, 0% de CPU en idle. El gasto real de batería viene de lo que estés corriendo, no de KeepAwake.
        """

        let tabSize = NSSize(width: 520, height: 420)
        let tabView = NSTabView(frame: NSRect(origin: .zero, size: tabSize))
        tabView.tabViewType = .topTabsBezelBorder

        for (title, text) in [("English", englishText), ("Español", spanishText)] {
            let scroll = NSScrollView(frame: NSRect(origin: .zero, size: tabSize))
            scroll.hasVerticalScroller = true
            scroll.hasHorizontalScroller = false
            scroll.autohidesScrollers = false
            scroll.borderType = .noBorder

            let tv = NSTextView(frame: NSRect(origin: .zero, size: tabSize))
            tv.isEditable = false
            tv.isSelectable = true
            tv.isRichText = false
            tv.font = NSFont.systemFont(ofSize: 13)
            tv.textContainerInset = NSSize(width: 10, height: 10)
            tv.string = text
            tv.isVerticallyResizable = true
            tv.isHorizontallyResizable = false
            tv.autoresizingMask = [.width]
            tv.textContainer?.containerSize = NSSize(width: tabSize.width, height: .greatestFiniteMagnitude)
            tv.textContainer?.widthTracksTextView = true

            scroll.documentView = tv

            let item = NSTabViewItem(identifier: title)
            item.label = title
            item.view = scroll
            tabView.addTabViewItem(item)
        }

        let alert = NSAlert()
        alert.messageText = "How KeepAwake works · Cómo funciona KeepAwake"
        alert.informativeText = "Switch tabs for English / Español."
        alert.accessoryView = tabView
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
        requestNotificationAuthIfNeeded()
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req)
    }

    private func requestNotificationAuthIfNeeded() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            if settings.authorizationStatus == .notDetermined {
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
                    if let e = error { Log.lifecycle.error("Notif auth error: \(e.localizedDescription)") }
                    Log.lifecycle.info("Notif auth granted=\(granted)")
                }
            }
        }
    }
}
