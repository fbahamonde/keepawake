import os

enum Log {
    static let subsystem = "com.felipe.keepawake"
    static let lifecycle = Logger(subsystem: subsystem, category: "lifecycle")
    static let state = Logger(subsystem: subsystem, category: "state")
    static let network = Logger(subsystem: subsystem, category: "network")
    static let assertion = Logger(subsystem: subsystem, category: "assertion")
    static let duration = Logger(subsystem: subsystem, category: "duration")
}
