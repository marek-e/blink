import Foundation
import OSLog

/// Logging categories. Messages record operations and error codes only: never URLs, hosts, rule
/// domains, or profile names.
enum Log {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "Blink"

    static let intake = Logger(subsystem: subsystem, category: "intake")
    static let dispatch = Logger(subsystem: subsystem, category: "dispatch")
    static let configuration = Logger(subsystem: subsystem, category: "configuration")
    static let profiles = Logger(subsystem: subsystem, category: "profiles")
    static let system = Logger(subsystem: subsystem, category: "system")
}

extension Error {
    /// Domain and code only; localized descriptions can embed URLs.
    var sanitizedCode: String {
        let error = self as NSError
        return "\(error.domain)#\(error.code)"
    }
}
