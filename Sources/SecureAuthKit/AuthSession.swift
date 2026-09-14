import Foundation

@MainActor
public final class AuthSession {
    private let authProvider: AuthProviding
    private let tokenStore: TokenStoring
    private let biometricAuthenticator: BiometricAuthenticating
    private let continuation: AsyncStream<AuthState>.Continuation
    private var state: AuthState

    public let stateStream: AsyncStream<AuthState>

    public init(
        authProvider: AuthProviding = MockAuthProvider(),
        tokenStore: TokenStoring = SecureTokenStore(),
        biometricAuthenticator: BiometricAuthenticating = BiometricAuthenticator()
    ) {
        self.authProvider = authProvider
        self.tokenStore = tokenStore
        self.biometricAuthenticator = biometricAuthenticator

        let stored = try? tokenStore.load()
        let initialState: AuthState = stored != nil ? .lockedBiometric : .loggedOut
        self.state = initialState

        var escapedContinuation: AsyncStream<AuthState>.Continuation!
        self.stateStream = AsyncStream { continuation in
            escapedContinuation = continuation
        }
        self.continuation = escapedContinuation
        self.continuation.yield(initialState)
    }

    deinit {
        continuation.finish()
    }

    /// The current state, readable synchronously so UI code can render the right screen on the
    /// very first frame instead of waiting for `stateStream` to deliver it asynchronously.
    public var currentState: AuthState { state }

    public func signIn(username: String, password: String) async throws {
        let token = try await authProvider.login(username: username, password: password)
        try tokenStore.save(token)
        setState(.authenticated(token))
    }

    public func unlockWithBiometrics() async throws {
        guard let token = try tokenStore.load() else {
            setState(.loggedOut)
            throw AuthError.noStoredToken
        }
        guard biometricAuthenticator.canAuthenticate() else {
            throw AuthError.biometryNotAvailable
        }
        guard try await biometricAuthenticator.authenticate(reason: "Unlock SecureAuthKit Demo") else {
            throw AuthError.biometryFailed
        }
        guard token.isExpired else {
            setState(.authenticated(token))
            return
        }
        // An expired stored token must not grant access on its own — exchange it for a fresh one
        // before authenticating, and fall back to `.loggedOut` if that exchange fails.
        do {
            let refreshedToken = try await authProvider.refresh(refreshToken: token.refreshToken)
            try tokenStore.save(refreshedToken)
            setState(.authenticated(refreshedToken))
        } catch {
            setState(.loggedOut)
            throw error
        }
    }

    /// Clears the stored credential and logs out.
    ///
    /// Throws if the Keychain deletion fails, leaving the state unchanged so the caller can
    /// retry rather than reporting a sign-out that left the credential on disk.
    public func signOut() throws {
        try tokenStore.clear()
        setState(.loggedOut)
    }

    public func currentToken() -> AuthToken? {
        if case .authenticated(let token) = state {
            return token
        }
        return nil
    }

    public func refreshTokenIfNeeded() async throws {
        guard case .authenticated(let token) = state, token.isExpired else {
            return
        }
        let newToken = try await authProvider.refresh(refreshToken: token.refreshToken)
        try tokenStore.save(newToken)
        setState(.authenticated(newToken))
    }

    private func setState(_ newState: AuthState) {
        state = newState
        continuation.yield(newState)
    }
}
