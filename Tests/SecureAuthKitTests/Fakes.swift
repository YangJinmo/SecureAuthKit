@testable import SecureAuthKit
import Foundation

final class FakeAuthProvider: AuthProviding, @unchecked Sendable {
    var loginResult: Result<AuthToken, Error> = .failure(AuthError.invalidCredentials)
    var refreshResult: Result<AuthToken, Error> = .failure(AuthError.tokenExpired)
    private(set) var refreshCallCount = 0

    func login(username: String, password: String) async throws -> AuthToken {
        try loginResult.get()
    }

    func refresh(refreshToken: String) async throws -> AuthToken {
        refreshCallCount += 1
        return try refreshResult.get()
    }
}

final class FakeTokenStore: TokenStoring, @unchecked Sendable {
    var storedToken: AuthToken?
    /// When set, `clear()` throws this instead of deleting, simulating a Keychain failure.
    var clearError: Error?
    private(set) var clearCallCount = 0

    func save(_ token: AuthToken) throws {
        storedToken = token
    }

    func load() throws -> AuthToken? {
        storedToken
    }

    func clear() throws {
        if let clearError {
            throw clearError
        }
        clearCallCount += 1
        storedToken = nil
    }
}

final class FakeBiometricAuthenticator: BiometricAuthenticating, @unchecked Sendable {
    var canAuthenticateResult = true
    var authenticateResult: Result<Bool, Error> = .success(true)

    func canAuthenticate() -> Bool {
        canAuthenticateResult
    }

    func authenticate(reason: String) async throws -> Bool {
        try authenticateResult.get()
    }
}
