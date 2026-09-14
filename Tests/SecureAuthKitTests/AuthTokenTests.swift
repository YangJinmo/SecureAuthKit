import XCTest
@testable import SecureAuthKit

final class AuthTokenTests: XCTestCase {
    func test_isExpired_returnsTrueForPastDate() {
        let token = AuthToken(accessToken: "a", refreshToken: "r", expiresAt: Date().addingTimeInterval(-10), subject: "demo")
        XCTAssertTrue(token.isExpired)
    }

    func test_isExpired_returnsFalseForFutureDate() {
        let token = AuthToken(accessToken: "a", refreshToken: "r", expiresAt: Date().addingTimeInterval(60), subject: "demo")
        XCTAssertFalse(token.isExpired)
    }
}
