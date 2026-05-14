import AppKit

final class StatusItemController {
    private let item: NSStatusItem
    private var leftClickHandler: () -> Void = {}
    private var rightClickHandler: () -> Void = {}
    private var cachedMenu: NSMenu?

    init() {
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.target = self
            button.action = #selector(handleClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.imagePosition = .imageOnly
        }
        update(for: .off, graceRemaining: nil)
    }

    func onClick(left: @escaping () -> Void, right: @escaping () -> Void) {
        self.leftClickHandler = left
        self.rightClickHandler = right
    }

    func setMenu(_ menu: NSMenu) {
        // Menu attached on-demand in handleClick so left-click can be intercepted
        self.cachedMenu = menu
    }

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        let isRight = event?.type == .rightMouseUp || (event?.modifierFlags.contains(.control) ?? false)
        if isRight {
            rightClickHandler()
            if let menu = cachedMenu {
                item.menu = menu
                sender.performClick(nil)
                item.menu = nil
            }
        } else {
            leftClickHandler()
        }
    }

    func update(for state: AppState, graceRemaining: TimeInterval?) {
        guard let button = item.button else { return }
        let (symbolName, badge) = symbolFor(state: state)
        let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "KeepAwake status")?
            .withSymbolConfiguration(config)
        if let badgeColor = badge {
            button.image = composite(base: image, badgeColor: badgeColor)
        } else {
            image?.isTemplate = true
            button.image = image
        }
        button.toolTip = tooltip(for: state, graceRemaining: graceRemaining)
    }

    private func symbolFor(state: AppState) -> (String, NSColor?) {
        switch state {
        case .off:
            return ("cup.and.saucer", nil)
        case .on:
            return ("cup.and.saucer.fill", nil)
        case .grace:
            return ("cup.and.saucer.fill", .systemOrange)
        case .paused:
            return ("cup.and.saucer", .systemGray)
        }
    }

    private func tooltip(for state: AppState, graceRemaining: TimeInterval?) -> String {
        switch state {
        case .off:
            return "KeepAwake: Off"
        case .on(let target, let current):
            if let t = target, let c = current {
                return "KeepAwake: On · \(c)\(c == t ? " ✓" : "")"
            }
            return "KeepAwake: On"
        case .grace(_, let current, _):
            let secs = Int(graceRemaining ?? 0)
            return "KeepAwake: On · \(current ?? "?") ✗ — pausing in \(secs)s"
        case .paused(let target):
            return "KeepAwake: Paused · waiting for \(target)"
        }
    }

    private func composite(base: NSImage?, badgeColor: NSColor) -> NSImage? {
        guard let base = base else { return nil }
        let size = base.size
        let result = NSImage(size: size)
        result.lockFocus()
        base.draw(at: .zero, from: NSRect(origin: .zero, size: size), operation: .sourceOver, fraction: 1.0)
        let dotSize: CGFloat = 5
        let dotRect = NSRect(x: size.width - dotSize - 1, y: 0, width: dotSize, height: dotSize)
        badgeColor.setFill()
        NSBezierPath(ovalIn: dotRect).fill()
        result.unlockFocus()
        result.isTemplate = false
        return result
    }
}
