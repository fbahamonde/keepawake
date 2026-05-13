import Foundation

final class DurationManager {
    private let clock: Clock
    private let onExpired: () -> Void
    private(set) var deadline: Date?
    private var hasFired = false

    init(clock: Clock = SystemClock(), onExpired: @escaping () -> Void) {
        self.clock = clock
        self.onExpired = onExpired
    }

    func start(duration: Duration) {
        hasFired = false
        if let seconds = duration.seconds {
            deadline = clock.now().addingTimeInterval(seconds)
        } else {
            deadline = nil
        }
        Log.duration.info("Duration started: \(duration.rawValue, privacy: .public)")
    }

    func stop() {
        deadline = nil
        hasFired = false
    }

    func check() {
        guard !hasFired, let d = deadline, clock.now() >= d else { return }
        hasFired = true
        Log.duration.info("Duration expired")
        onExpired()
    }

    var remainingSeconds: TimeInterval? {
        guard let d = deadline else { return nil }
        return max(0, d.timeIntervalSince(clock.now()))
    }
}
