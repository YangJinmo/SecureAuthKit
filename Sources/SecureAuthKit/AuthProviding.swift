public protocol AuthProviding: Sendable {
    func login(username: String, password: String) async throws -> AuthToken
    func refresh(refreshToken: String) async throws -> AuthToken
}
