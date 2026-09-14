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

    /// Regression test: refresh tokens outlive the provider instance that issued them, because
    /// the `AuthToken` persists in the Keychain while a fresh `MockAuthProvider` is constructed
    /// on every app launch. Refresh must succeed across that boundary.
    func test_refresh_acrossFreshProviderInstance_succeeds() async throws {
        let original = try await makeProvider().login(username: "demo", password: "password123")

        let freshProvider = makeProvider()
        let refreshed = try await freshProvider.refresh(refreshToken: original.refreshToken)

        XCTAssertEqual(refreshed.subject, original.subject)
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

    func test_refresh_withMalformedRefreshTokens_throwsTokenExpired() async {
        let provider = makeProvider()
        let malformedTokens = [
            "",                                             // empty
            "demo",                                         // no separator
            "-\(UUID().uuidString)",                        // empty subject
            "demo-",                                        // empty suffix
            "demo-not-a-uuid"                               // suffix is not a UUID
        ]

        for malformed in malformedTokens {
            do {
                _ = try await provider.refresh(refreshToken: malformed)
                XCTFail("Expected refresh to throw for \(malformed.debugDescription)")
            } catch {
                XCTAssertEqual(error as? AuthError, .tokenExpired, "for \(malformed.debugDescription)")
            }
        }
    }
}
