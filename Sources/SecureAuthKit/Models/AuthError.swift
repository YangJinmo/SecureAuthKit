import Foundation

public enum AuthError: Error, LocalizedError, Equatable, Sendable {
    case invalidCredentials
    case biometryNotAvailable
    case biometryFailed
    case tokenExpired
    case noStoredToken
    case keychainError(OSStatus)

    public var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "The username or password is incorrect."
        case .biometryNotAvailable:
            return "Biometric authentication is not available on this device."
        case .biometryFailed:
            return "Biometric authentication failed."
        case .tokenExpired:
            return "Your session has expired. Please sign in again."
        case .noStoredToken:
            return "No saved session was found."
        case .keychainError(let status):
            return "A secure storage error occurred (code \(status))."
        }
    }
}
