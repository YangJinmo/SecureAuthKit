import XCTest
@testable import SecureAuthKit

/// `BiometricAuthenticator` has no automated tests, deliberately.
///
/// Its entire body is a thin wrapper over `LAContext`, and `LAContext` cannot be exercised from
/// XCTest: `canEvaluatePolicy` reports on real device state (biometric enrollment, passcode,
/// lockout counters) and `evaluatePolicy` presents a system-owned Face ID / Touch ID sheet that
/// only a human — or the Simulator's *Features → Face ID* menu — can answer. There is no seam
/// Apple provides to stub either one, and a test that injected a fake `LAContext` would only be
/// testing the fake.
///
/// What *is* testable is the calling logic layered on top, and that is covered:
/// `AuthSessionTests` drives `AuthSession` against `FakeBiometricAuthenticator`
/// (`Tests/SecureAuthKitTests/Fakes.swift`), asserting the behavior for each outcome the real
/// authenticator can produce — biometrics unavailable, a failed match, and a successful unlock.
///
/// The real `LAContext` path is verified manually on the Simulator with Face ID enrolled, per
/// the "Running the demo app" section of `README.md`.
///
/// This file intentionally contains no test methods; it exists to document the gap where a
/// reader would otherwise look for one.
final class BiometricAuthenticatorTests: XCTestCase {}
