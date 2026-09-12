import XCTest
@testable import SecureAuthKit

final class MockAuthProviderTests: XCTestCase {
    private func makeProvider() -> MockAuthProvider {
        MockAuthProvider(loginDelayNanoseconds: 0, refreshDelayNanoseconds: 0)
    }

    func test_login_withValidCredentials_returnsToken() async throws {
        let provider = makeProvider()

        let token = try await provider.login(username: "demo", password: "password123")

        XCTAssertEqual(token.subject, "demo")
        XCTAssertFalse(token.accessToken.isEmpty)
        XCTAssertFalse(token.refreshToken.isEmpty)
    }

    func test_login_withInvalidCredentials_throwsInvalidCredentials() async {
        let provider = makeProvider()

        do {
            _ = try await provider.login(username: "demo", password: "wrong")
            XCTFail("Expected login to throw")
        } catch {
            XCTAssertEqual(error as? AuthError, .invalidCredentials)
        }
    }

    func test_refresh_withTokenFromLogin_returnsNewToken() async throws {
        let provider = makeProvider()
        let original = try await provider.login(username: "demo", password: "password123")

        let refreshed = try await provider.refresh(refreshToken: original.refreshToken)

        XCTAssertEqual(refreshed.subject, "demo")
        XCTAssertNotEqual(refreshed.accessToken, original.accessToken)
    }

    func test_refresh_withUnknownRefreshToken_throwsTokenExpired() async {
        let provider = makeProvider()

        do {
            _ = try await provider.refresh(refreshToken: "not-a-real-token")
            XCTFail("Expected refresh to throw")
        } catch {
            XCTAssertEqual(error as? AuthError, .tokenExpired)
        }
    }
}
