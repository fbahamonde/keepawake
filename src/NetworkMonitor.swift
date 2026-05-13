import Foundation
import CoreWLAN

protocol SSIDProvider {
    func currentSSID() -> String?
}

final class CoreWLANSSIDProvider: SSIDProvider {
    private let client = CWWiFiClient.shared()
    func currentSSID() -> String? {
        client.interface()?.ssid()
    }
}

enum NetworkEvent: Equatable {
    case matched(ssid: String?)
    case graceStarted(ssid: String?, deadline: Date)
    case paused
    case resumed(ssid: String?)
    case unknown
}

final class NetworkMonitor {
    private let ssidProvider: SSIDProvider
    private let clock: Clock
    private let gracePeriod: TimeInterval
    private let nilToleranceCount: Int
    private let onEvent: (NetworkEvent) -> Void

    private var target: String?
    private var consecutiveNilReads = 0
    private var graceDeadline: Date?
    private var isPaused = false
    private var previousLoggedEvent: NetworkEvent?

    init(ssidProvider: SSIDProvider,
         clock: Clock = SystemClock(),
         gracePeriod: TimeInterval = 60,
         nilToleranceCount: Int = 3,
         onEvent: @escaping (NetworkEvent) -> Void) {
        self.ssidProvider = ssidProvider
        self.clock = clock
        self.gracePeriod = gracePeriod
        self.nilToleranceCount = nilToleranceCount
        self.onEvent = onEvent
    }

    func setTarget(_ newTarget: String?) {
        let wasActive = (graceDeadline != nil) || isPaused
        target = newTarget
        graceDeadline = nil
        if wasActive {
            evaluate()
        }
    }

    func tick() {
        evaluate()
    }

    private func evaluate() {
        let current = ssidProvider.currentSSID()

        if current == nil {
            consecutiveNilReads += 1
            if consecutiveNilReads < nilToleranceCount {
                emit(.unknown)
                return
            }
            // Fall through to treat as mismatch
        } else {
            consecutiveNilReads = 0
        }

        let matched = (target == nil) || (current != nil && current == target)

        if matched {
            graceDeadline = nil
            if isPaused {
                isPaused = false
                emit(.resumed(ssid: current))
            } else {
                emit(.matched(ssid: current))
            }
            return
        }

        // Mismatch
        if isPaused {
            return
        }

        if let deadline = graceDeadline {
            if clock.now() >= deadline {
                graceDeadline = nil
                isPaused = true
                emit(.paused)
            }
            return
        }

        graceDeadline = clock.now().addingTimeInterval(gracePeriod)
        emit(.graceStarted(ssid: current, deadline: graceDeadline!))
    }

    private func emit(_ event: NetworkEvent) {
        if event != previousLoggedEvent {
            Log.network.debug("event=\(String(describing: event), privacy: .public)")
            previousLoggedEvent = event
        }
        onEvent(event)
    }
}
