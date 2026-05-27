import Foundation

enum WakeState {
    case idle
    case waking
    case success
    case failed(String)

    var caption: String {
        switch self {
        case .idle:
            return "Idle"
        case .waking:
            return "Checking..."
        case .success:
            return "Online"
        case .failed(let error):
            return error
        }
    }
}
