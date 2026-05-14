import AppKit

final class MenuBuilder {
    struct Callbacks {
        let toggleKeepAwake: () -> Void
        let setDuration: (Duration) -> Void
        let setTargetCurrent: () -> Void
        let clearTarget: () -> Void
        let toggleLaunchAtLogin: () -> Void
        let toggleKeepDisplayAwake: () -> Void
        let showAbout: () -> Void
        let showHelp: () -> Void
        let openLocationSettings: () -> Void
        let quit: () -> Void
    }

    func build(state: AppState,
               target: String?,
               currentSSID: String?,
               duration: Duration,
               launchAtLogin: Bool,
               keepDisplayAwake: Bool,
               locationAuthorized: Bool,
               callbacks: Callbacks) -> NSMenu {
        let menu = NSMenu()

        menu.addItem(headerItem(state: state, currentSSID: currentSSID))
        if !locationAuthorized && target != nil {
            let item = NSMenuItem(title: "Grant Location permission to validate network",
                                  action: #selector(MenuActionRelay.run(_:)),
                                  keyEquivalent: "")
            item.target = MenuActionRelay.shared
            item.representedObject = callbacks.openLocationSettings as Any
            menu.addItem(item)
        }
        menu.addItem(.separator())

        let toggle = NSMenuItem(title: "Keep Awake",
                                action: #selector(MenuActionRelay.run(_:)),
                                keyEquivalent: "")
        toggle.target = MenuActionRelay.shared
        toggle.representedObject = callbacks.toggleKeepAwake as Any
        toggle.state = state.isAssertionHeld ? .on : .off
        menu.addItem(toggle)

        let durationItem = NSMenuItem(title: "Duration", action: nil, keyEquivalent: "")
        let durationMenu = NSMenu()
        for d in Duration.allCases {
            let mi = NSMenuItem(title: d.label, action: #selector(MenuActionRelay.run(_:)), keyEquivalent: "")
            mi.target = MenuActionRelay.shared
            let action: () -> Void = { callbacks.setDuration(d) }
            mi.representedObject = action as Any
            mi.state = (d == duration) ? .on : .off
            durationMenu.addItem(mi)
        }
        durationItem.submenu = durationMenu
        menu.addItem(durationItem)

        let netLabel: String
        if let t = target { netLabel = "Only on network: \(t)" } else { netLabel = "Only on network: (none)" }
        let netItem = NSMenuItem(title: netLabel, action: nil, keyEquivalent: "")
        let netMenu = NSMenu()

        if let t = target {
            let cur = NSMenuItem(title: "✓ \(t)", action: nil, keyEquivalent: "")
            cur.isEnabled = false
            netMenu.addItem(cur)
            netMenu.addItem(.separator())
        }

        let setCurrentTitle: String
        if let c = currentSSID {
            setCurrentTitle = "Set current Wi-Fi as target  (\(c))"
        } else {
            setCurrentTitle = "Set current Wi-Fi as target  (none)"
        }
        let setItem = NSMenuItem(title: setCurrentTitle, action: #selector(MenuActionRelay.run(_:)), keyEquivalent: "")
        setItem.target = MenuActionRelay.shared
        setItem.representedObject = callbacks.setTargetCurrent as Any
        setItem.isEnabled = currentSSID != nil
        netMenu.addItem(setItem)

        let clearItem = NSMenuItem(title: "Clear target", action: #selector(MenuActionRelay.run(_:)), keyEquivalent: "")
        clearItem.target = MenuActionRelay.shared
        clearItem.representedObject = callbacks.clearTarget as Any
        clearItem.isEnabled = target != nil
        netMenu.addItem(clearItem)

        netItem.submenu = netMenu
        menu.addItem(netItem)

        menu.addItem(.separator())

        let displayItem = NSMenuItem(title: "Keep display awake too", action: #selector(MenuActionRelay.run(_:)), keyEquivalent: "")
        displayItem.target = MenuActionRelay.shared
        displayItem.representedObject = callbacks.toggleKeepDisplayAwake as Any
        displayItem.state = keepDisplayAwake ? .on : .off
        displayItem.toolTip = "Also prevent the screen from sleeping. Uses more battery."
        menu.addItem(displayItem)

        let loginItem = NSMenuItem(title: "Launch at Login", action: #selector(MenuActionRelay.run(_:)), keyEquivalent: "")
        loginItem.target = MenuActionRelay.shared
        loginItem.representedObject = callbacks.toggleLaunchAtLogin as Any
        loginItem.state = launchAtLogin ? .on : .off
        menu.addItem(loginItem)

        let help = NSMenuItem(title: "How it works…", action: #selector(MenuActionRelay.run(_:)), keyEquivalent: "?")
        help.target = MenuActionRelay.shared
        help.representedObject = callbacks.showHelp as Any
        menu.addItem(help)

        let about = NSMenuItem(title: "About KeepAwake", action: #selector(MenuActionRelay.run(_:)), keyEquivalent: "")
        about.target = MenuActionRelay.shared
        about.representedObject = callbacks.showAbout as Any
        menu.addItem(about)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit", action: #selector(MenuActionRelay.run(_:)), keyEquivalent: "q")
        quit.target = MenuActionRelay.shared
        quit.representedObject = callbacks.quit as Any
        menu.addItem(quit)

        return menu
    }

    private func headerItem(state: AppState, currentSSID: String?) -> NSMenuItem {
        let title: String
        switch state {
        case .off:
            title = "KeepAwake — Off"
        case .on(let target, let current):
            if let t = target, let c = current {
                title = "KeepAwake — On · \(c)\(c == t ? " ✓" : "")"
            } else {
                title = "KeepAwake — On"
            }
        case .grace(_, let current, let deadline):
            let remaining = Int(max(0, deadline.timeIntervalSinceNow))
            title = "KeepAwake — On · \(current ?? "?") ✗ — pausing in \(remaining)s"
        case .paused(let target):
            title = "KeepAwake — Paused · waiting for \(target)"
        }
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }
}

final class MenuActionRelay: NSObject {
    static let shared = MenuActionRelay()

    @objc func run(_ sender: NSMenuItem) {
        guard let block = sender.representedObject as? () -> Void else { return }
        block()
    }
}
