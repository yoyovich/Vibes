import Foundation
import Observation

/// Collects user-facing error messages so failures are never silently ignored.
@MainActor
@Observable
final class ErrorCenter {
    var message: String?

    func report(_ text: String) {
        message = text
    }

    func report(_ error: Error, while action: String) {
        let detail = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        message = "\(action)\n\(detail)"
    }
}
