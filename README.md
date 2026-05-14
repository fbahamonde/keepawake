[Versión en español](README.es.md)

# KeepAwake

A tiny macOS menubar app that prevents system idle sleep, with optional Wi-Fi-based gating.

![CI](https://img.shields.io/badge/CI-passing-brightgreen)
![License](https://img.shields.io/badge/license-MIT-blue)
![macOS](https://img.shields.io/badge/macOS-14%2B-lightgrey)
![Arch](https://img.shields.io/badge/arch-Apple%20Silicon-black)

![menubar](docs/screenshot.png)

---

> ## Important limitation
>
> **KeepAwake does NOT keep your Mac awake with the lid closed on battery.**
>
> On Apple Silicon, lid-closed-on-battery sleep is enforced by firmware below the kernel. No software — not KeepAwake, not `caffeinate`, not Amphetamine — can bypass it. KeepAwake only helps with **lid-open** scenarios (or lid-closed while plugged into power + external display, when macOS already supports clamshell mode).
>
> If you need code to run while your Mac is closed on battery, use a remote dev box and SSH from your phone.

## Features

- One-click toggle in the menubar (cup-and-saucer icon, fills when active).
- Duration presets: 15 min, 1h, 2h, 5h, indefinite, or "until lid closes".
- Optional Wi-Fi gating: only keep awake when connected to a chosen SSID, with a 60-second grace period on network changes.
- Launch at Login toggle.
- Auto-off notification when a timed session ends.
- ~20 MB RAM, 0% CPU when idle. No third-party dependencies.
- Ad-hoc signed, runs entirely locally, no telemetry.

## Install

### Pre-built (from Releases)

1. Download `KeepAwake.zip` from the [Releases](../../releases) page and unzip it.
2. Strip the quarantine attribute (the build is ad-hoc signed, not notarized):
   ```bash
   xattr -d com.apple.quarantine KeepAwake.app
   ```
3. Move it into your Applications folder:
   ```bash
   mv KeepAwake.app ~/Applications/
   open ~/Applications/KeepAwake.app
   ```

### From source

```bash
git clone https://github.com/fbahamonde/keepawake.git
cd keepawake
./build.sh
cp -R KeepAwake.app ~/Applications/
open ~/Applications/KeepAwake.app
```

Requirements: macOS 14+ on Apple Silicon, Xcode Command Line Tools (`xcode-select --install`).

## Usage

- **Left-click** the menubar icon to toggle Keep Awake on/off. Filled icon = on.
- **Right-click** to open the menu.

### Duration

Pick how long the session should last:

- `15 minutes` / `1 hour` / `2 hours` / `5 hours` — auto-off when the timer expires, with a notification.
- `Indefinitely` — stays on until you turn it off.
- `Until lid closes` — turns off when you close the lid.

### Wi-Fi gating

Optional. Only keep awake when connected to a specific network.

1. Connect to the Wi-Fi you want as the target (for example, your phone's hotspot).
2. Menu → `Only on network` → `Set current Wi-Fi as target`.
3. If you switch networks, KeepAwake gives you a 60-second grace period (icon shows an orange badge with a countdown). If you don't reconnect, the assertion is released and the menu shows `Paused · waiting for <target>`.
4. Reconnecting to the target SSID re-acquires the assertion automatically.

With no target set, KeepAwake works everywhere without checking the network.

### Icon states

| Icon | Meaning |
| --- | --- |
| Outline | Off |
| Filled | On, network OK (or no target set) |
| Filled + orange badge | On, wrong network, 60s countdown |
| Outline + grey | Paused, waiting to return to target network |

## Why does it ask for Location permission?

macOS classifies the Wi-Fi SSID as sensitive data — knowing your network name can reveal where you are. Apps can only read the SSID with "Location When In Use" permission granted. KeepAwake uses it **only** to compare the current SSID against your configured target.

Without Location permission, basic Keep Awake still works; only the Wi-Fi gating feature is disabled. The app never records your location and the SSID never leaves your machine.

## Development

```bash
swift test       # 38 XCTest cases
./build.sh       # build KeepAwake.app
```

File structure:

```
src/                Swift sources (AppDelegate, status item, assertion controller, Wi-Fi monitor, ...)
tests/              XCTest target (KeepAwakeTests)
Info.plist          Bundle metadata, LSUIElement, location usage description
build.sh            swiftc + codesign --force --deep -s -
Package.swift       SwiftPM manifest, used for `swift test` only
SMOKE_TEST.md       Hand-run checklist before declaring a build good
```

## Architecture

- **`IOPMAssertionCreateWithName`** (`PreventUserIdleSystemSleep`) — the actual "keep awake" mechanism.
- **CoreWLAN + CoreLocation** — read the current SSID for Wi-Fi gating.
- **AppKit** — `NSStatusItem`, menu, notifications. `LSUIElement = true` keeps the app out of the Dock and `Cmd-Tab`.
- **ServiceManagement** — launch-at-login toggle (`SMAppService`).
- **UserNotifications** — "session ended" notification when a timer expires.

No third-party dependencies. Built with `swiftc` directly (no Xcode project), ad-hoc signed (`codesign -s -`).

Bundle ID: `com.felipe.keepawake`.

## Contributing

This is a personal tool, but issues and PRs are welcome. If you find a bug, the easiest fix is usually a focused PR with a regression test in `tests/`. Keep the dependency footprint at zero, please.

## License

[MIT](LICENSE) © 2026 Felipe Bahamonde. Personal tool, no warranty.
