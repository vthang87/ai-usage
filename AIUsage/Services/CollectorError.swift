import Foundation

enum CollectorError: LocalizedError {
    case timeout
    case processFailed(String)
    case rpc(String)
    case notAuthenticated
    case missingToken
    case unexpectedResponse(String)

    var errorDescription: String? {
        switch self {
        case .timeout:
            "Timed out waiting for CLI"
        case let .processFailed(message):
            message
        case let .rpc(message):
            message
        case .notAuthenticated:
            "Not signed in"
        case .missingToken:
            "No local access token"
        case let .unexpectedResponse(message):
            message
        }
    }
}
