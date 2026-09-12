import Security
import XCTest
@testable import SecureAuthKit

@MainActor
final class AuthSessionTests: XCTestCase {
    func test_init_withNoStoredToken_startsLoggedOut() {
        let session = AuthSession(authProvider: FakeAuthProvider(), tokenStore: FakeTokenStore(), biometricAuthenticator: FakeBiometricAuthenticator())

        XCTAssertNil(session.currentToken())
    }

    func test_init_withStoredToken_startsLockedBiometric() async {
        let tokenStore = FakeTokenStore()
        tokenStore.storedToken = AuthToken(accessToken: "a", refreshToken: "r", expiresAt: Date().addingTimeInterval(60), subject: "demo")
        let session = AuthSession(authProvider: FakeAuthProvider(), tokenStore: tokenStore, biometricAuthenticator: FakeBiometricAuthenticator())

        var iterator = session.stateStream.makeAsyncIterator()
        let firstState = await iterator.next()

        XCTAssertEqual(firstState, .lockedBiometric)
        XCTAssertEqual(session.currentState, .lockedBiometric)
    }

    func test_signIn_withValidCredentials_savesTokenAndAuthenticates() async throws {
        let expectedToken = AuthToken(accessToken: "a", refreshToken: "r", expiresAt: Date().addingTimeInterval(60), subject: "demo")
        let authProvider = FakeAuthProvider()
        authProvider.loginResult = .success(expectedToken)
        let tokenStore = FakeTokenStore()
        let session = AuthSession(authProvider: authProvider, tokenStore: tokenStore, biometricAuthenticator: FakeBiometricAuthenticator())

        try await session.signIn(username: "demo", password: "password123")

        XCTAssertEqual(session.currentToken(), expectedToken)
        XCTAssertEqual(tokenStore.storedToken, expectedToken)
    }

    func test_signIn_withInvalidCredentials_throwsAndDoesNotAuthenticate() async {
        let authProvider = FakeAuthProvider()
        authProvider.loginResult = .failure(AuthError.invalidCredentials)
        let session = AuthSession(authProvider: authProvider, tokenStore: FakeTokenStore(), biometricAuthenticator: FakeBiometricAuthenticator())

        do {
            try await session.signIn(username: "demo", password: "wrong")
            XCTFail("Expected signIn to throw")
        } catch {
            XCTAssertEqual(error as? AuthError, .invalidCredentials)
        }
        XCTAssertNil(session.currentToken())
    }

    func test_unlockWithBiometrics_withStoredTokenAndSuccess_authenticates() async throws {
        let storedToken = AuthToken(accessToken: "a", refreshToken: "r", expiresAt: Date().addingTimeInterval(60), subject: "demo")
        let tokenStore = FakeTokenStore()
        tokenStore.storedToken = storedToken
        let session = AuthSession(authProvider: FakeAuthProvider(), tokenStore: tokenStore, biometricAuthenticator: FakeBiometricAuthenticator())

        try await session.unlockWithBiometrics()

        XCTAssertEqual(session.currentToken(), storedToken)
    }

    func test_unlockWithBiometrics_withoutStoredToken_throwsNoStoredToken() async {
        let session = AuthSession(authProvider: FakeAuthProvider(), tokenStore: FakeTokenStore(), biometricAuthenticator: FakeBiometricAuthenticator())

        do {
            try await session.unlockWithBiometrics()
            XCTFail("Expected unlockWithBiometrics to throw")
        } catch {
            XCTAssertEqual(error as? AuthError, .noStoredToken)
        }
    }

    func test_unlockWithBiometrics_whenBiometricsUnavailable_throwsBiometryNotAvailable() async {
        let tokenStore = FakeTokenStore()
        tokenStore.storedToken = AuthToken(accessToken: "a", refreshToken: "r", expiresAt: Date().addingTimeInterval(60), subject: "demo")
        let biometrics = FakeBiometricAuthenticator()
        biometrics.canAuthenticateResult = false
        let session = AuthSession(authProvider: FakeAuthProvider(), tokenStore: tokenStore, biometricAuthenticator: biometrics)

        do {
            try await session.unlockWithBiometrics()
            XCTFail("Expected unlockWithBiometrics to throw")
        } catch {
            XCTAssertEqual(error as? AuthError, .biometryNotAvailable)
        }
        XCTAssertNil(session.currentToken())
    }

    func test_unlockWithBiometrics_withExpiredStoredToken_refreshesAndAuthenticates() async throws {
        let expiredToken = AuthToken(accessToken: "old", refreshToken: "r1", expiresAt: Date().addingTimeInterval(-10), subject: "demo")
        let refreshedToken = AuthToken(accessToken: "new", refreshToken: "r2", expiresAt: Date().addingTimeInterval(60), subject: "demo")
        let authProvider = FakeAuthProvider()
        authProvider.refreshResult = .success(refreshedToken)
        let tokenStore = FakeTokenStore()
        tokenStore.storedToken = expiredToken
        let session = AuthSession(authProvider: authProvider, tokenStore: tokenStore, biometricAuthenticator: FakeBiometricAuthenticator())

        try await session.unlockWithBiometrics()

        XCTAssertEqual(session.currentState, .authenticated(refreshedToken))
        XCTAssertEqual(session.currentToken(), refreshedToken)
        XCTAssertEqual(tokenStore.storedToken, refreshedToken)
        XCTAssertEqual(authProvider.refreshCallCount, 1)
    }

    func test_unlockWithBiometrics_withExpiredStoredTokenAndFailingRefresh_throwsAndLogsOut() async {
        let expiredToken = AuthToken(accessToken: "old", refreshToken: "r1", expiresAt: Date().addingTimeInterval(-10), subject: "demo")
        let authProvider = FakeAuthProvider()
        authProvider.refreshResult = .failure(AuthError.tokenExpired)
        let tokenStore = FakeTokenStore()
        tokenStore.storedToken = expiredToken
        let session = AuthSession(authProvider: authProvider, tokenStore: tokenStore, biometricAuthenticator: FakeBiometricAuthenticator())

        do {
            try await session.unlockWithBiometrics()
            XCTFail("Expected unlockWithBiometrics to throw")
        } catch {
            XCTAssertEqual(error as? AuthError, .tokenExpired)
        }
        XCTAssertEqual(session.currentState, .loggedOut)
        XCTAssertNil(session.currentToken())
    }

    func test_refreshTokenIfNeeded_withExpiredToken_refreshesAndSaves() async throws {
        let expiredToken = AuthToken(accessToken: "old", refreshToken: "r1", expiresAt: Date().addingTimeInterval(-10), subject: "demo")
        let refreshedToken = AuthToken(accessToken: "new", refreshToken: "r2", expiresAt: Date().addingTimeInterval(60), subject: "demo")
        let authProvider = FakeAuthProvider()
        authProvider.loginResult = .success(expiredToken)
        authProvider.refreshResult = .success(refreshedToken)
        let tokenStore = FakeTokenStore()
        let session = AuthSession(authProvider: authProvider, tokenStore: tokenStore, biometricAuthenticator: FakeBiometricAuthenticator())
        try await session.signIn(username: "demo", password: "password123")

        try await session.refreshTokenIfNeeded()

        XCTAssertEqual(session.currentToken(), refreshedToken)
        XCTAssertEqual(tokenStore.storedToken, refreshedToken)
        XCTAssertEqual(authProvider.refreshCallCount, 1)
    }

    func test_signOut_clearsTokenAndLogsOut() async throws {
        let token = AuthToken(accessToken: "a", refreshToken: "r", expiresAt: Date().addingTimeInterval(60), subject: "demo")
        let authProvider = FakeAuthProvider()
        authProvider.loginResult = .success(token)
        let tokenStore = FakeTokenStore()
        let session = AuthSession(authProvider: authProvider, tokenStore: tokenStore, biometricAuthenticator: FakeBiometricAuthenticator())
        try await session.signIn(username: "demo", password: "password123")

        try session.signOut()

        XCTAssertNil(session.currentToken())
        XCTAssertEqual(session.currentState, .loggedOut)
        XCTAssertEqual(tokenStore.clearCallCount, 1)
    }

    func test_signOut_whenClearFails_propagatesErrorAndStaysAuthenticated() async throws {
        let token = AuthToken(accessToken: "a", refreshToken: "r", expiresAt: Date().addingTimeInterval(60), subject: "demo")
        let authProvider = FakeAuthProvider()
        authProvider.loginResult = .success(token)
        let tokenStore = FakeTokenStore()
        let session = AuthSession(authProvider: authProvider, tokenStore: tokenStore, biometricAuthenticator: FakeBiometricAuthenticator())
        try await session.signIn(username: "demo", password: "password123")
        tokenStore.clearError = AuthError.keychainError(errSecInteractionNotAllowed)

        do {
            try session.signOut()
            XCTFail("Expected signOut to throw")
        } catch {
            XCTAssertEqual(error as? AuthError, .keychainError(errSecInteractionNotAllowed))
        }
        XCTAssertEqual(session.currentState, .authenticated(token))
        XCTAssertEqual(session.currentToken(), token)
        XCTAssertEqual(tokenStore.storedToken, token)
    }
}
