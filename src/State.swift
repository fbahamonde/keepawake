import Foundation

enum AppState: Equatable {
    case off
    case on(targetSSID: String?, currentSSID: String?)
    case grace(targetSSID: String, currentSSID: String?, deadline: Date)
    case paused(targetSSID: String)

    var isAssertionHeld: Bool {
        switch self {
        case .off, .paused: return false
        case .on, .grace: return true
        }
    }
}

enum Duration: String, CaseIterable {
    case fifteenMin = "15m"
    case oneHour = "1h"
    case twoHours = "2h"
    case fiveHours = "5h"
    case indefinite = "indef"
    case untilLidClose = "untilLidClose"

    var seconds: TimeInterval? {
        switch self {
        case .fifteenMin: return 15 * 60
        case .oneHour: return 3600
        case .twoHours: return 2 * 3600
        case .fiveHours: return 5 * 3600
        case .indefinite, .untilLidClose: return nil
        }
    }

    var label: String {
        switch self {
        case .fifteenMin: return "15 minutes"
        case .oneHour: return "1 hour"
        case .twoHours: return "2 hours"
        case .fiveHours: return "5 hours"
        case .indefinite: return "Indefinitely"
        case .untilLidClose: return "Until lid closes"
        }
    }
}

protocol Clock {
    func now() -> Date
}

struct SystemClock: Clock {
    func now() -> Date { Date() }
}
