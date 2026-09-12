# SecureAuthKit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build `SecureAuthKit`, a Swift Package providing biometric authentication and secure token storage, plus a SwiftUI demo app exercising the full login → biometric unlock → token refresh → logout flow.

**Architecture:** A single SPM package (`SecureAuthKit`) with no SwiftUI/Combine dependency — plain Swift, async/await, and `AsyncStream` for state changes. Four internal components (`BiometricAuthenticator`, `SecureTokenStore`, `MockAuthProvider`, and the `AuthSession` facade that composes them) sit behind small protocols for testability. A separate Xcode app project (`SecureAuthKitDemo`, generated via XcodeGen) consumes the package as a local dependency and wraps `AuthSession` in an `ObservableObject`.

**Tech Stack:** Swift 5.9 tools / Swift 5 language mode, `LocalAuthentication`, `Security` (Keychain), `XCTest`, SwiftUI, XcodeGen (build-time only, not a runtime dependency).

**Spec:** [docs/superpowers/specs/2026-09-12-secureauthkit-design.md](../specs/2026-09-12-secureauthkit-design.md)

## Global Constraints

- Minimum platform: iOS 16. Package also declares macOS 13 support so `swift test` can run directly on the host Mac without a simulator.
- `swift-tools-version: 5.9` (Swift 5 language mode) — keeps concurrency diagnostics as warnings rather than hard errors, appropriate for an example project.
- No third-party runtime dependencies in the SDK — only Apple's `Security` and `LocalAuthentication` frameworks.
- Every public type behind a protocol (`AuthProviding`, `TokenStoring`, `BiometricAuthenticating`) so `AuthSession` can be unit tested with fakes.
- Mock demo credentials: username `demo`, password `password123` (documented in code and in the login screen).
- Demo app project is generated with XcodeGen from `SecureAuthKitDemo/project.yml`; the generated `.xcodeproj` is committed so the project opens directly in Xcode without requiring XcodeGen.

---

## Task 1: Package scaffold and core models

**Files:**
- Create: `Package.swift`
- Create: `Sources/SecureAuthKit/Models/AuthToken.swift`
- Create: `Sources/SecureAuthKit/Models/AuthState.swift`
- Create: `Sources/SecureAuthKit/Models/AuthError.swift`
- Test: `Tests/SecureAuthKitTests/AuthTokenTests.swift`
- Test: `Tests/SecureAuthKitTests/AuthErrorTests.swift`

**Interfaces:**
- Produces: `AuthToken` (struct: `accessToken: String`, `refreshToken: String`, `expiresAt: Date`, `subject: String`, computed `isExpired: Bool`), `AuthState` (enum: `.loggedOut`, `.lockedBiometric`, `.authenticated(AuthToken)`), `AuthError` (enum: `.invalidCredentials`, `.biometryNotAvailable`, `.biometryFailed`, `.tokenExpired`, `.noStoredToken`, `.keychainError(OSStatus)`, conforms to `Error`, `LocalizedError`, `Equatable`).

- [ ] **Step 1: Create the package manifest**

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SecureAuthKit",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "SecureAuthKit", targets: ["SecureAuthKit"])
    ],
    targets: [
        .target(name: "SecureAuthKit"),
        .testTarget(name: "SecureAuthKitTests", dependencies: ["SecureAuthKit"])
    ]
)
```

Save as `Package.swift` at the repo root.

- [ ] **Step 2: Create the `AuthToken` stub (no behavior yet)**

```swift
import Foundation

public struct AuthToken: Codable, Equatable, Sendable {
    public let accessToken: String
    public let refreshToken: String
    public let expiresAt: Date
    public let subject: String

    public init(accessToken: String, refreshToken: String, expiresAt: Date, subject: String) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
        self.subject = subject
    }
}
```

Save as `Sources/SecureAuthKit/Models/AuthToken.swift`.

- [ ] **Step 3: Write the failing test for `isExpired`**

```swift
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
```

Save as `Tests/SecureAuthKitTests/AuthTokenTests.swift`.

- [ ] **Step 4: Run the test to verify it fails**

Run: `swift test --filter AuthTokenTests`
Expected: FAIL to compile — `value of type 'AuthToken' has no member 'isExpired'`

- [ ] **Step 5: Add `isExpired` to `AuthToken`**

Add this computed property inside the `AuthToken` struct from Step 2:

```swift
    public var isExpired: Bool {
        Date() >= expiresAt
    }
```

- [ ] **Step 6: Run the test to verify it passes**

Run: `swift test --filter AuthTokenTests`
Expected: PASS (2 tests)

- [ ] **Step 7: Create `AuthState` (plain data, no logic to test)**

```swift
public enum AuthState: Equatable, Sendable {
    case loggedOut
    case lockedBiometric
    case authenticated(AuthToken)
}
```

Save as `Sources/SecureAuthKit/Models/AuthState.swift`.

- [ ] **Step 8: Create the `AuthError` stub without descriptions**

```swift
public enum AuthError: Error, Equatable, Sendable {
    case invalidCredentials
    case biometryNotAvailable
    case biometryFailed
    case tokenExpired
    case noStoredToken
    case keychainError(OSStatus)
}
```

Save as `Sources/SecureAuthKit/Models/AuthError.swift`.

- [ ] **Step 9: Write the failing test for error descriptions**

```swift
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
```

Save as `Tests/SecureAuthKitTests/AuthErrorTests.swift`.

- [ ] **Step 10: Run the test to verify it fails**

Run: `swift test --filter AuthErrorTests`
Expected: FAIL — `errorDescription` is `nil` (protocol not adopted yet), assertion fails

- [ ] **Step 11: Conform `AuthError` to `LocalizedError`**

Change the `AuthError` declaration line from Step 8 to:

```swift
public enum AuthError: Error, LocalizedError, Equatable, Sendable {
```

Add this computed property inside the enum:

```swift
    public var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "The username or password is incorrect."
        case .biometryNotAvailable:
            return "Biometric authentication is not available on this device."
        case .biometryFailed:
            return "Biometric authentication failed."
        case .tokenExpired:
            return "Your session has expired. Please sign in again."
        case .noStoredToken:
            return "No saved session was found."
        case .keychainError(let status):
            return "A secure storage error occurred (code \(status))."
        }
    }
```

- [ ] **Step 12: Run the tests to verify they pass**

Run: `swift test --filter AuthErrorTests`
Expected: PASS (3 tests)

- [ ] **Step 13: Commit**

```bash
git add Package.swift Sources/SecureAuthKit/Models Tests/SecureAuthKitTests/AuthTokenTests.swift Tests/SecureAuthKitTests/AuthErrorTests.swift
git commit -m "feat: add AuthToken, AuthState, AuthError models"
```

---

## Task 2: SecureTokenStore (Keychain wrapper)

**Files:**
- Create: `Sources/SecureAuthKit/TokenStoring.swift`
- Create: `Sources/SecureAuthKit/SecureTokenStore.swift`
- Test: `Tests/SecureAuthKitTests/SecureTokenStoreTests.swift`

**Interfaces:**
- Consumes: `AuthToken` (Task 1), `AuthError.keychainError(OSStatus)` (Task 1)
- Produces: `protocol TokenStoring { func save(_ token: AuthToken) throws; func load() throws -> AuthToken?; func clear() throws }`, `final class SecureTokenStore: TokenStoring` with `init(service: String = "com.secureauthkit.tokenstore")`

- [ ] **Step 1: Create the `TokenStoring` protocol**

```swift
public protocol TokenStoring: Sendable {
    func save(_ token: AuthToken) throws
    func load() throws -> AuthToken?
    func clear() throws
}
```

Save as `Sources/SecureAuthKit/TokenStoring.swift`.

- [ ] **Step 2: Write the failing tests**

```swift
import XCTest
@testable import SecureAuthKit

final class SecureTokenStoreTests: XCTestCase {
    private var store: SecureTokenStore!

    override func setUp() {
        super.setUp()
        store = SecureTokenStore(service: "com.secureauthkit.tokenstore.tests")
        try? store.clear()
    }

    override func tearDown() {
        try? store.clear()
        store = nil
        super.tearDown()
    }

    func test_load_withNothingSaved_returnsNil() throws {
        XCTAssertNil(try store.load())
    }

    func test_saveThenLoad_returnsSameToken() throws {
        let token = AuthToken(accessToken: "a1", refreshToken: "r1", expiresAt: Date().addingTimeInterval(3600), subject: "demo")

        try store.save(token)
        let loaded = try store.load()

        XCTAssertEqual(loaded, token)
    }

    func test_saveTwice_overwritesPreviousToken() throws {
        let first = AuthToken(accessToken: "a1", refreshToken: "r1", expiresAt: Date().addingTimeInterval(3600), subject: "demo")
        let second = AuthToken(accessToken: "a2", refreshToken: "r2", expiresAt: Date().addingTimeInterval(3600), subject: "demo")

        try store.save(first)
        try store.save(second)

        XCTAssertEqual(try store.load(), second)
    }

    func test_clear_removesToken() throws {
        let token = AuthToken(accessToken: "a1", refreshToken: "r1", expiresAt: Date().addingTimeInterval(3600), subject: "demo")
        try store.save(token)

        try store.clear()

        XCTAssertNil(try store.load())
    }
}
```

Save as `Tests/SecureAuthKitTests/SecureTokenStoreTests.swift`.

- [ ] **Step 3: Run the tests to verify they fail**

Run: `swift test --filter SecureTokenStoreTests`
Expected: FAIL to compile — `SecureTokenStore` does not exist

- [ ] **Step 4: Implement `SecureTokenStore`**

```swift
import Foundation
import Security

public final class SecureTokenStore: TokenStoring, Sendable {
    private let service: String
    private let account = "currentUser"

    public init(service: String = "com.secureauthkit.tokenstore") {
        self.service = service
    }

    public func save(_ token: AuthToken) throws {
        let data = try JSONEncoder().encode(token)
        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(baseQuery as CFDictionary)

        var attributes = baseQuery
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw AuthError.keychainError(status)
        }
    }

    public func load() throws -> AuthToken? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess, let data = item as? Data else {
            throw AuthError.keychainError(status)
        }
        return try JSONDecoder().decode(AuthToken.self, from: data)
    }

    public func clear() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw AuthError.keychainError(status)
        }
    }
}
```

Save as `Sources/SecureAuthKit/SecureTokenStore.swift`.

- [ ] **Step 5: Run the tests to verify they pass**

Run: `swift test --filter SecureTokenStoreTests`
Expected: PASS (4 tests). Note: this exercises the real macOS login Keychain from the test process. If you see a Keychain access prompt the first time, allow it — subsequent runs should not prompt since the test binary owns the item it created.

- [ ] **Step 6: Commit**

```bash
git add Sources/SecureAuthKit/TokenStoring.swift Sources/SecureAuthKit/SecureTokenStore.swift Tests/SecureAuthKitTests/SecureTokenStoreTests.swift
git commit -m "feat: add SecureTokenStore Keychain-backed token storage"
```

---

## Task 3: MockAuthProvider

**Files:**
- Create: `Sources/SecureAuthKit/AuthProviding.swift`
- Create: `Sources/SecureAuthKit/MockAuthProvider.swift`
- Test: `Tests/SecureAuthKitTests/MockAuthProviderTests.swift`

**Interfaces:**
- Consumes: `AuthToken`, `AuthError.invalidCredentials`, `AuthError.tokenExpired` (Task 1)
- Produces: `protocol AuthProviding { func login(username: String, password: String) async throws -> AuthToken; func refresh(refreshToken: String) async throws -> AuthToken }`, `actor MockAuthProvider: AuthProviding` with `init(validUsername: String = "demo", validPassword: String = "password123", tokenLifetime: TimeInterval = 60, loginDelayNanoseconds: UInt64 = 500_000_000, refreshDelayNanoseconds: UInt64 = 300_000_000)`

- [ ] **Step 1: Create the `AuthProviding` protocol**

```swift
public protocol AuthProviding: Sendable {
    func login(username: String, password: String) async throws -> AuthToken
    func refresh(refreshToken: String) async throws -> AuthToken
}
```

Save as `Sources/SecureAuthKit/AuthProviding.swift`.

- [ ] **Step 2: Write the failing tests**

```swift
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
```

Save as `Tests/SecureAuthKitTests/MockAuthProviderTests.swift`.

- [ ] **Step 3: Run the tests to verify they fail**

Run: `swift test --filter MockAuthProviderTests`
Expected: FAIL to compile — `MockAuthProvider` does not exist

- [ ] **Step 4: Implement `MockAuthProvider`**

```swift
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
```

Save as `Sources/SecureAuthKit/MockAuthProvider.swift`.

- [ ] **Step 5: Run the tests to verify they pass**

Run: `swift test --filter MockAuthProviderTests`
Expected: PASS (4 tests)

- [ ] **Step 6: Commit**

```bash
git add Sources/SecureAuthKit/AuthProviding.swift Sources/SecureAuthKit/MockAuthProvider.swift Tests/SecureAuthKitTests/MockAuthProviderTests.swift
git commit -m "feat: add MockAuthProvider simulated login/refresh"
```

---

## Task 4: BiometricAuthenticator

**Files:**
- Create: `Sources/SecureAuthKit/BiometricAuthenticating.swift`
- Create: `Sources/SecureAuthKit/BiometricAuthenticator.swift`

**Interfaces:**
- Consumes: `AuthError.biometryNotAvailable`, `AuthError.biometryFailed` (Task 1)
- Produces: `protocol BiometricAuthenticating { func canAuthenticate() -> Bool; func authenticate(reason: String) async throws -> Bool }`, `final class BiometricAuthenticator: BiometricAuthenticating`

No automated test: `LAContext`'s real biometric prompt cannot be exercised by `XCTest` (it requires actual hardware/Simulator UI interaction). This class is verified manually in Task 7's end-to-end walkthrough, and `AuthSession`'s tests (Task 5) exercise the calling logic against a fake implementation of `BiometricAuthenticating`.

- [ ] **Step 1: Create the `BiometricAuthenticating` protocol**

```swift
public protocol BiometricAuthenticating: Sendable {
    func canAuthenticate() -> Bool
    func authenticate(reason: String) async throws -> Bool
}
```

Save as `Sources/SecureAuthKit/BiometricAuthenticating.swift`.

- [ ] **Step 2: Implement `BiometricAuthenticator`**

```swift
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
```

Save as `Sources/SecureAuthKit/BiometricAuthenticator.swift`.

- [ ] **Step 3: Verify it compiles**

Run: `swift build`
Expected: build succeeds with no errors

- [ ] **Step 4: Commit**

```bash
git add Sources/SecureAuthKit/BiometricAuthenticating.swift Sources/SecureAuthKit/BiometricAuthenticator.swift
git commit -m "feat: add BiometricAuthenticator LocalAuthentication wrapper"
```

---

## Task 5: AuthSession facade

**Files:**
- Create: `Sources/SecureAuthKit/AuthSession.swift`
- Test: `Tests/SecureAuthKitTests/Fakes.swift`
- Test: `Tests/SecureAuthKitTests/AuthSessionTests.swift`

**Interfaces:**
- Consumes: `AuthToken`, `AuthState`, `AuthError` (Task 1); `TokenStoring` (Task 2); `AuthProviding`, `MockAuthProvider` (Task 3); `BiometricAuthenticating`, `BiometricAuthenticator` (Task 4)
- Produces: `@MainActor public final class AuthSession` with `init(authProvider: AuthProviding = MockAuthProvider(), tokenStore: TokenStoring = SecureTokenStore(), biometricAuthenticator: BiometricAuthenticating = BiometricAuthenticator())`, `public let stateStream: AsyncStream<AuthState>`, `func signIn(username:password:) async throws`, `func unlockWithBiometrics() async throws`, `func signOut()`, `func currentToken() -> AuthToken?`, `func refreshTokenIfNeeded() async throws`

- [ ] **Step 1: Create test fakes**

```swift
@testable import SecureAuthKit
import Foundation

final class FakeAuthProvider: AuthProviding, @unchecked Sendable {
    var loginResult: Result<AuthToken, Error> = .failure(AuthError.invalidCredentials)
    var refreshResult: Result<AuthToken, Error> = .failure(AuthError.tokenExpired)
    private(set) var refreshCallCount = 0

    func login(username: String, password: String) async throws -> AuthToken {
        try loginResult.get()
    }

    func refresh(refreshToken: String) async throws -> AuthToken {
        refreshCallCount += 1
        return try refreshResult.get()
    }
}

final class FakeTokenStore: TokenStoring, @unchecked Sendable {
    var storedToken: AuthToken?
    private(set) var clearCallCount = 0

    func save(_ token: AuthToken) throws {
        storedToken = token
    }

    func load() throws -> AuthToken? {
        storedToken
    }

    func clear() throws {
        clearCallCount += 1
        storedToken = nil
    }
}

final class FakeBiometricAuthenticator: BiometricAuthenticating, @unchecked Sendable {
    var canAuthenticateResult = true
    var authenticateResult: Result<Bool, Error> = .success(true)

    func canAuthenticate() -> Bool {
        canAuthenticateResult
    }

    func authenticate(reason: String) async throws -> Bool {
        try authenticateResult.get()
    }
}
```

Save as `Tests/SecureAuthKitTests/Fakes.swift`.

- [ ] **Step 2: Write the failing tests**

```swift
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

    func test_refreshTokenIfNeeded_withExpiredToken_refreshesAndSaves() async throws {
        let expiredToken = AuthToken(accessToken: "old", refreshToken: "r1", expiresAt: Date().addingTimeInterval(-10), subject: "demo")
        let refreshedToken = AuthToken(accessToken: "new", refreshToken: "r2", expiresAt: Date().addingTimeInterval(60), subject: "demo")
        let authProvider = FakeAuthProvider()
        authProvider.refreshResult = .success(refreshedToken)
        let tokenStore = FakeTokenStore()
        tokenStore.storedToken = expiredToken
        let session = AuthSession(authProvider: authProvider, tokenStore: tokenStore, biometricAuthenticator: FakeBiometricAuthenticator())
        try await session.unlockWithBiometrics()

        try await session.refreshTokenIfNeeded()

        XCTAssertEqual(session.currentToken(), refreshedToken)
        XCTAssertEqual(authProvider.refreshCallCount, 1)
    }

    func test_signOut_clearsTokenAndLogsOut() async throws {
        let token = AuthToken(accessToken: "a", refreshToken: "r", expiresAt: Date().addingTimeInterval(60), subject: "demo")
        let authProvider = FakeAuthProvider()
        authProvider.loginResult = .success(token)
        let tokenStore = FakeTokenStore()
        let session = AuthSession(authProvider: authProvider, tokenStore: tokenStore, biometricAuthenticator: FakeBiometricAuthenticator())
        try await session.signIn(username: "demo", password: "password123")

        session.signOut()

        XCTAssertNil(session.currentToken())
        XCTAssertEqual(tokenStore.clearCallCount, 1)
    }
}
```

Save as `Tests/SecureAuthKitTests/AuthSessionTests.swift`.

- [ ] **Step 3: Run the tests to verify they fail**

Run: `swift test --filter AuthSessionTests`
Expected: FAIL to compile — `AuthSession` does not exist

- [ ] **Step 4: Implement `AuthSession`**

```swift
import Foundation

@MainActor
public final class AuthSession {
    private let authProvider: AuthProviding
    private let tokenStore: TokenStoring
    private let biometricAuthenticator: BiometricAuthenticating
    private let continuation: AsyncStream<AuthState>.Continuation
    private var state: AuthState

    public let stateStream: AsyncStream<AuthState>

    public init(
        authProvider: AuthProviding = MockAuthProvider(),
        tokenStore: TokenStoring = SecureTokenStore(),
        biometricAuthenticator: BiometricAuthenticating = BiometricAuthenticator()
    ) {
        self.authProvider = authProvider
        self.tokenStore = tokenStore
        self.biometricAuthenticator = biometricAuthenticator

        let stored = try? tokenStore.load()
        let initialState: AuthState = stored != nil ? .lockedBiometric : .loggedOut
        self.state = initialState

        var escapedContinuation: AsyncStream<AuthState>.Continuation!
        self.stateStream = AsyncStream { continuation in
            escapedContinuation = continuation
        }
        self.continuation = escapedContinuation
        self.continuation.yield(initialState)
    }

    public func signIn(username: String, password: String) async throws {
        let token = try await authProvider.login(username: username, password: password)
        try tokenStore.save(token)
        setState(.authenticated(token))
    }

    public func unlockWithBiometrics() async throws {
        guard let token = try tokenStore.load() else {
            setState(.loggedOut)
            throw AuthError.noStoredToken
        }
        guard biometricAuthenticator.canAuthenticate() else {
            throw AuthError.biometryNotAvailable
        }
        guard try await biometricAuthenticator.authenticate(reason: "Unlock SecureAuthKit Demo") else {
            throw AuthError.biometryFailed
        }
        setState(.authenticated(token))
    }

    public func signOut() {
        try? tokenStore.clear()
        setState(.loggedOut)
    }

    public func currentToken() -> AuthToken? {
        if case .authenticated(let token) = state {
            return token
        }
        return nil
    }

    public func refreshTokenIfNeeded() async throws {
        guard case .authenticated(let token) = state, token.isExpired else {
            return
        }
        let newToken = try await authProvider.refresh(refreshToken: token.refreshToken)
        try tokenStore.save(newToken)
        setState(.authenticated(newToken))
    }

    private func setState(_ newState: AuthState) {
        state = newState
        continuation.yield(newState)
    }
}
```

Save as `Sources/SecureAuthKit/AuthSession.swift`.

- [ ] **Step 5: Run the tests to verify they pass**

Run: `swift test --filter AuthSessionTests`
Expected: PASS (8 tests)

- [ ] **Step 6: Run the full package test suite**

Run: `swift test`
Expected: All tests pass (AuthTokenTests, AuthErrorTests, SecureTokenStoreTests, MockAuthProviderTests, AuthSessionTests)

- [ ] **Step 7: Commit**

```bash
git add Sources/SecureAuthKit/AuthSession.swift Tests/SecureAuthKitTests/Fakes.swift Tests/SecureAuthKitTests/AuthSessionTests.swift
git commit -m "feat: add AuthSession facade orchestrating auth flow"
```

---

## Task 6: Demo app project scaffold

**Files:**
- Create: `SecureAuthKitDemo/project.yml`
- Create: `SecureAuthKitDemo/SecureAuthKitDemo/SecureAuthKitDemoApp.swift`
- Create (generated): `SecureAuthKitDemo/SecureAuthKitDemo.xcodeproj`

**Interfaces:**
- Consumes: the `SecureAuthKit` package (local path dependency, one level up from `SecureAuthKitDemo/`)
- Produces: a buildable iOS app target named `SecureAuthKitDemo`

- [ ] **Step 1: Install XcodeGen if not already installed**

Run: `which xcodegen || brew install xcodegen`
Expected: `xcodegen` is available on PATH afterwards

- [ ] **Step 2: Create the XcodeGen project spec**

```yaml
name: SecureAuthKitDemo
options:
  bundleIdPrefix: com.secureauthkit
packages:
  SecureAuthKit:
    path: ..
targets:
  SecureAuthKitDemo:
    type: application
    platform: iOS
    deploymentTarget: "16.0"
    sources:
      - path: SecureAuthKitDemo
    dependencies:
      - package: SecureAuthKit
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.secureauthkit.demo
        MARKETING_VERSION: "1.0"
        CURRENT_PROJECT_VERSION: "1"
        SWIFT_VERSION: "5.0"
        TARGETED_DEVICE_FAMILY: "1,2"
        GENERATE_INFOPLIST_FILE: YES
        INFOPLIST_KEY_NSFaceIDUsageDescription: "SecureAuthKit Demo uses Face ID to unlock your saved session."
        INFOPLIST_KEY_UILaunchScreen_Generation: YES
```

Save as `SecureAuthKitDemo/project.yml`.

- [ ] **Step 3: Create a placeholder app entry point**

```swift
import SwiftUI

@main
struct SecureAuthKitDemoApp: App {
    var body: some Scene {
        WindowGroup {
            Text("SecureAuthKit Demo")
                .padding()
        }
    }
}
```

Save as `SecureAuthKitDemo/SecureAuthKitDemo/SecureAuthKitDemoApp.swift`.

- [ ] **Step 4: Generate the Xcode project**

Run: `cd SecureAuthKitDemo && xcodegen generate && cd ..`
Expected: `Created project at SecureAuthKitDemo/SecureAuthKitDemo.xcodeproj`

- [ ] **Step 5: Build the app for the simulator**

Run: `xcodebuild -project SecureAuthKitDemo/SecureAuthKitDemo.xcodeproj -scheme SecureAuthKitDemo -destination 'generic/platform=iOS Simulator' build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 6: Commit**

```bash
git add SecureAuthKitDemo/project.yml SecureAuthKitDemo/SecureAuthKitDemo/SecureAuthKitDemoApp.swift SecureAuthKitDemo/SecureAuthKitDemo.xcodeproj
git commit -m "feat: scaffold SecureAuthKitDemo app project via XcodeGen"
```

---

## Task 7: Demo app view layer and state wiring

**Files:**
- Create: `SecureAuthKitDemo/SecureAuthKitDemo/ViewModels/AuthViewModel.swift`
- Create: `SecureAuthKitDemo/SecureAuthKitDemo/Views/RootView.swift`
- Create: `SecureAuthKitDemo/SecureAuthKitDemo/Views/LoginView.swift`
- Create: `SecureAuthKitDemo/SecureAuthKitDemo/Views/BiometricLockView.swift`
- Create: `SecureAuthKitDemo/SecureAuthKitDemo/Views/HomeView.swift`
- Modify: `SecureAuthKitDemo/SecureAuthKitDemo/SecureAuthKitDemoApp.swift`

**Interfaces:**
- Consumes: `AuthSession`, `AuthState`, `AuthToken` (Task 5, via `import SecureAuthKit`)
- Produces: `@MainActor final class AuthViewModel: ObservableObject` with `@Published private(set) var state: AuthState`, `@Published var errorMessage: String?`, `var currentToken: AuthToken?`, `func signIn(username:password:) async`, `func unlockWithBiometrics() async`, `func refreshToken() async`, `func signOut() async`

No automated tests: SwiftUI view behavior is verified manually against the Simulator in this task's final step, per the spec's scope (automated tests are for the SDK layer; the demo app is exercised end-to-end by hand).

- [ ] **Step 1: Create `AuthViewModel`**

```swift
import Foundation
import SecureAuthKit

@MainActor
final class AuthViewModel: ObservableObject {
    @Published private(set) var state: AuthState = .loggedOut
    @Published var errorMessage: String?

    private let session: AuthSession
    private var observationTask: Task<Void, Never>?

    init(session: AuthSession = AuthSession()) {
        self.session = session
        observationTask = Task { [weak self] in
            guard let self else { return }
            for await newState in self.session.stateStream {
                self.state = newState
            }
        }
    }

    deinit {
        observationTask?.cancel()
    }

    var currentToken: AuthToken? {
        if case .authenticated(let token) = state {
            return token
        }
        return nil
    }

    func signIn(username: String, password: String) async {
        do {
            try await session.signIn(username: username, password: password)
            errorMessage = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Something went wrong."
        }
    }

    func unlockWithBiometrics() async {
        do {
            try await session.unlockWithBiometrics()
            errorMessage = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Something went wrong."
        }
    }

    func refreshToken() async {
        do {
            try await session.refreshTokenIfNeeded()
            errorMessage = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Something went wrong."
        }
    }

    func signOut() async {
        session.signOut()
    }
}
```

Save as `SecureAuthKitDemo/SecureAuthKitDemo/ViewModels/AuthViewModel.swift`.

- [ ] **Step 2: Create `LoginView`**

```swift
import SwiftUI

struct LoginView: View {
    @ObservedObject var viewModel: AuthViewModel
    @State private var username = "demo"
    @State private var password = "password123"
    @State private var isSigningIn = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Sign In") {
                    TextField("Username", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("Password", text: $password)
                }
                Section {
                    Text("Demo credentials: demo / password123")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Button {
                    Task {
                        isSigningIn = true
                        await viewModel.signIn(username: username, password: password)
                        isSigningIn = false
                    }
                } label: {
                    if isSigningIn {
                        ProgressView()
                    } else {
                        Text("Sign In")
                    }
                }
                .disabled(isSigningIn)
            }
            .navigationTitle("SecureAuthKit Demo")
            .alert("Sign In Failed", isPresented: errorBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }
}
```

Save as `SecureAuthKitDemo/SecureAuthKitDemo/Views/LoginView.swift`.

- [ ] **Step 3: Create `BiometricLockView`**

```swift
import SwiftUI

struct BiometricLockView: View {
    @ObservedObject var viewModel: AuthViewModel

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "faceid")
                .font(.system(size: 64))
            Text("Unlock to continue")
                .font(.headline)
            Button("Unlock") {
                Task { await viewModel.unlockWithBiometrics() }
            }
            .buttonStyle(.borderedProminent)
            if let message = viewModel.errorMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
        .padding()
        .task {
            await viewModel.unlockWithBiometrics()
        }
    }
}
```

Save as `SecureAuthKitDemo/SecureAuthKitDemo/Views/BiometricLockView.swift`.

- [ ] **Step 4: Create `HomeView`**

```swift
import SwiftUI
import SecureAuthKit

struct HomeView: View {
    @ObservedObject var viewModel: AuthViewModel

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                if let token = viewModel.currentToken {
                    Text("Signed in as \(token.subject)")
                        .font(.headline)
                    Text("Expires at \(token.expiresAt.formatted(date: .omitted, time: .standard))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Button("Refresh Token") {
                    Task { await viewModel.refreshToken() }
                }
                .buttonStyle(.bordered)
                Button("Sign Out", role: .destructive) {
                    Task { await viewModel.signOut() }
                }
                .buttonStyle(.bordered)
                if let message = viewModel.errorMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
                Spacer()
            }
            .padding()
            .navigationTitle("Home")
        }
    }
}
```

Save as `SecureAuthKitDemo/SecureAuthKitDemo/Views/HomeView.swift`.

- [ ] **Step 5: Create `RootView`**

```swift
import SwiftUI

struct RootView: View {
    @ObservedObject var viewModel: AuthViewModel

    var body: some View {
        switch viewModel.state {
        case .loggedOut:
            LoginView(viewModel: viewModel)
        case .lockedBiometric:
            BiometricLockView(viewModel: viewModel)
        case .authenticated:
            HomeView(viewModel: viewModel)
        }
    }
}
```

Save as `SecureAuthKitDemo/SecureAuthKitDemo/Views/RootView.swift`.

- [ ] **Step 6: Wire `RootView` into the app entry point**

Replace the contents of `SecureAuthKitDemo/SecureAuthKitDemo/SecureAuthKitDemoApp.swift` with:

```swift
import SwiftUI

@main
struct SecureAuthKitDemoApp: App {
    @StateObject private var viewModel = AuthViewModel()

    var body: some Scene {
        WindowGroup {
            RootView(viewModel: viewModel)
        }
    }
}
```

- [ ] **Step 7: Regenerate the Xcode project so new files are included**

Run: `cd SecureAuthKitDemo && xcodegen generate && cd ..`
Expected: `Created project at SecureAuthKitDemo/SecureAuthKitDemo.xcodeproj`

- [ ] **Step 8: Build the app**

Run: `xcodebuild -project SecureAuthKitDemo/SecureAuthKitDemo.xcodeproj -scheme SecureAuthKitDemo -destination 'generic/platform=iOS Simulator' build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 9: Manually verify the full flow on a simulator**

Install and launch the built app on a booted iOS Simulator (via Xcode's Run button, or `xcrun simctl install`/`launch`), with the Simulator's **Features → Face ID → Enrolled** option turned on, then walk through:
1. Launch with no stored session → `LoginView` appears, pre-filled with `demo` / `password123`.
2. Tap **Sign In** → after a short delay, `HomeView` appears showing "Signed in as demo" and an expiry time.
3. Force-quit and relaunch the app → `BiometricLockView` appears and automatically triggers a Face ID prompt (use Simulator's **Features → Face ID → Matching Face** to approve it).
4. After a successful match, `HomeView` appears again with the same token.
5. Tap **Sign Out** → `LoginView` reappears.
6. Sign in again, then tap **Refresh Token** on `HomeView` before the token expires — since it isn't expired yet, the token and expiry time should stay unchanged (this is expected: `refreshTokenIfNeeded` only calls the provider when the token is actually expired).

- [ ] **Step 10: Commit**

```bash
git add SecureAuthKitDemo
git commit -m "feat: implement demo app login, biometric unlock, and home views"
```

---

## Task 8: Documentation and final verification

**Files:**
- Create: `README.md`

- [ ] **Step 1: Write the README**

```markdown
# SecureAuthKit

An example iOS authentication SDK demonstrating biometric authentication and
secure token storage, plus a SwiftUI demo app exercising the full flow.

## What's included

- **`SecureAuthKit`** (Swift Package, `Sources/SecureAuthKit`) — the SDK:
  - `BiometricAuthenticator` — Face ID / Touch ID via `LocalAuthentication`
  - `SecureTokenStore` — Keychain-backed token storage via `Security`
  - `MockAuthProvider` — simulates a login/token-refresh backend (no network)
  - `AuthSession` — the public facade composing the three above
- **`SecureAuthKitDemo`** (SwiftUI app, generated with [XcodeGen](https://github.com/yonaskolb/XcodeGen)) —
  consumes `SecureAuthKit` as a local package dependency and demonstrates
  login → biometric unlock on relaunch → token refresh → sign out.

## What's intentionally out of scope

- Real network/backend integration (see `MockAuthProvider`)
- OAuth2/OIDC social login
- App Attest / DeviceCheck device integrity verification

See `docs/superpowers/specs/2026-09-12-secureauthkit-design.md` for the full
design rationale.

## Building and testing the SDK

```bash
swift test
```

Runs on macOS directly (no simulator needed) since the package also declares
macOS 13 as a supported platform for fast local testing.

## Running the demo app

```bash
cd SecureAuthKitDemo
xcodegen generate   # only needed after adding/removing source files
open SecureAuthKitDemo.xcodeproj
```

Build and run on an iOS Simulator with **Features → Face ID → Enrolled**
turned on so the biometric prompts work. Demo credentials: `demo` / `password123`.
```

Save as `README.md` at the repo root.

- [ ] **Step 2: Run the full SDK test suite one more time**

Run: `swift test`
Expected: all tests pass

- [ ] **Step 3: Build the demo app one more time**

Run: `xcodebuild -project SecureAuthKitDemo/SecureAuthKitDemo.xcodeproj -scheme SecureAuthKitDemo -destination 'generic/platform=iOS Simulator' build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add README.md
git commit -m "docs: add README covering SDK usage and demo app instructions"
```
