import LocalAuthentication

public final class BiometricAuthenticator: BiometricAuthenticating, Sendable {
    public init() {}

    public func canAuthenticate() -> Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    public func authenticate(reason: String) async throws -> Bool {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            throw AuthError.biometryNotAvailable
        }
        return try await withCheckedThrowingContinuation { continuation in
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, _ in
                if success {
                    continuation.resume(returning: true)
                } else {
                    continuation.resume(throwing: AuthError.biometryFailed)
                }
            }
        }
    }
}
