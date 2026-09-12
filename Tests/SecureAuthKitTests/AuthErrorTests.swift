import XCTest
@testable import SecureAuthKit

final class AuthErrorTests: XCTestCase {
    func test_invalidCredentials_hasDescription() {
        XCTAssertEqual(AuthError.invalidCredentials.errorDescription, "The username or password is incorrect.")
    }

    func test_biometryNotAvailable_hasDescription() {
        XCTAssertEqual(AuthError.biometryNotAvailable.errorDescription, "Biometric authentication is not available on this device.")
    }

    func test_keychainError_includesStatusCode() {
        XCTAssertEqual(AuthError.keychainError(-25300).errorDescription, "A secure storage error occurred (code -25300).")
    }
}
