import Foundation

final class Preferences {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var targetSSID: String? {
        get { defaults.string(forKey: "targetSSID") }
        set {
            if let v = newValue {
                defaults.set(v, forKey: "targetSSID")
            } else {
                defaults.removeObject(forKey: "targetSSID")
            }
        }
    }

    var duration: Duration {
        get {
            let raw = defaults.string(forKey: "duration") ?? Duration.indefinite.rawValue
            return Duration(rawValue: raw) ?? .indefinite
        }
        set { defaults.set(newValue.rawValue, forKey: "duration") }
    }

    var launchAtLogin: Bool {
        get { defaults.bool(forKey: "launchAtLogin") }
        set { defaults.set(newValue, forKey: "launchAtLogin") }
    }

    var keepDisplayAwake: Bool {
        get { defaults.bool(forKey: "keepDisplayAwake") }
        set { defaults.set(newValue, forKey: "keepDisplayAwake") }
    }
}
