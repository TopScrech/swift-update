import Foundation

public enum UpdateError: LocalizedError {
    case message(String)

    public var errorDescription: String? {
        switch self {
        case .message(let message): message
        }
    }
}
