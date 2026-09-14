import Foundation

public actor MockAuthProvider: AuthProviding {
    private let validUsername: String
    private let validPassword: String
    private let tokenLifetime: TimeInterval
    private let loginDelayNanoseconds: UInt64
    private let refreshDelayNanoseconds: UInt64

    public init(
        validUsername: String = "demo",
        validPassword: String = "password123",
        tokenLifetime: TimeInterval = 60,
        loginDelayNanoseconds: UInt64 = 500_000_000,
        refreshDelayNanoseconds: UInt64 = 300_000_000
    ) {
        self.validUsername = validUsername
        self.validPassword = validPassword
        self.tokenLifetime = tokenLifetime
        self.loginDelayNanoseconds = loginDelayNanoseconds
        self.refreshDelayNanoseconds = refreshDelayNanoseconds
    }

    public func login(username: String, password: String) async throws -> AuthToken {
        try await Task.sleep(nanoseconds: loginDelayNanoseconds)
        guard username == validUsername, password == validPassword else {
            throw AuthError.invalidCredentials
        }
        return issueToken(subject: username)
    }

    public func refresh(refreshToken: String) async throws -> AuthToken {
        try await Task.sleep(nanoseconds: refreshDelayNanoseconds)
        guard let subject = Self.subject(fromRefreshToken: refreshToken) else {
            throw AuthError.tokenExpired
        }
        return issueToken(subject: subject)
    }

    /// Recovers the subject a refresh token was issued for, or `nil` if the token is malformed.
    ///
    /// Refresh tokens are self-describing — shaped `"<subject>-<UUID>"` — rather than opaque
    /// handles looked up in an in-memory map. That matters because the provider is constructed
    /// fresh on every app launch while the `AuthToken` itself outlives the process in the
    /// Keychain: a map-based provider would reject every token issued before the last relaunch.
    /// A real backend behaves the same way, validating a self-contained credential (a JWT, say)
    /// structurally rather than consulting per-client state it never kept.
    ///
    /// Only the first `-` separates the two halves, so a subject that itself contains a `-`
    /// would not round-trip. The demo's fixed `demo` username contains none.
    private static func subject(fromRefreshToken refreshToken: String) -> String? {
        guard let separatorIndex = refreshToken.firstIndex(of: "-") else {
            return nil
        }
        let subject = String(refreshToken[refreshToken.startIndex..<separatorIndex])
        let suffix = String(refreshToken[refreshToken.index(after: separatorIndex)...])
        guard !subject.isEmpty, UUID(uuidString: suffix) != nil else {
            return nil
        }
        return subject
    }

    private func issueToken(subject: String) -> AuthToken {
        AuthToken(
            accessToken: UUID().uuidString,
            refreshToken: "\(subject)-\(UUID().uuidString)",
            expiresAt: Date().addingTimeInterval(tokenLifetime),
            subject: subject
        )
    }
}
