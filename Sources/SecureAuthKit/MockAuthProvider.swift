import Foundation

public actor MockAuthProvider: AuthProviding {
    private let validUsername: String
    private let validPassword: String
    private let tokenLifetime: TimeInterval
    private let loginDelayNanoseconds: UInt64
    private let refreshDelayNanoseconds: UInt64
    private var refreshTokenSubjects: [String: String] = [:]

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
        guard let subject = refreshTokenSubjects.removeValue(forKey: refreshToken) else {
            throw AuthError.tokenExpired
        }
        return issueToken(subject: subject)
    }

    private func issueToken(subject: String) -> AuthToken {
        let refreshToken = UUID().uuidString
        refreshTokenSubjects[refreshToken] = subject
        return AuthToken(
            accessToken: UUID().uuidString,
            refreshToken: refreshToken,
            expiresAt: Date().addingTimeInterval(tokenLifetime),
            subject: subject
        )
    }
}
