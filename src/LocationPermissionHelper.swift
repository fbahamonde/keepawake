import CoreLocation
import AppKit

final class LocationPermissionHelper: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var onChange: ((CLAuthorizationStatus) -> Void)?

    override init() {
        super.init()
        manager.delegate = self
    }

    var status: CLAuthorizationStatus {
        manager.authorizationStatus
    }

    var isAuthorized: Bool {
        switch status {
        case .authorizedAlways, .authorizedWhenInUse: return true
        default: return false
        }
    }

    func requestIfNeeded(onChange: @escaping (CLAuthorizationStatus) -> Void) {
        self.onChange = onChange
        if status == .notDetermined {
            manager.requestWhenInUseAuthorization()
        } else {
            onChange(status)
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Log.network.info("Location auth status changed: \(manager.authorizationStatus.rawValue)")
        onChange?(manager.authorizationStatus)
    }

    static func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices") {
            NSWorkspace.shared.open(url)
        }
    }
}
