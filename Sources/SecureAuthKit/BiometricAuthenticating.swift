public protocol BiometricAuthenticating: Sendable {
    func canAuthenticate() -> Bool
    func authenticate(reason: String) async throws -> Bool
}
