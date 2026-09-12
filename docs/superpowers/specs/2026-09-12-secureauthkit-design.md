# SecureAuthKit — Design Spec

Date: 2026-09-12

## Purpose

A portfolio-quality example project demonstrating iOS security/authentication
SDK design. Consists of a standalone Swift Package (`SecureAuthKit`) providing
biometric authentication and secure token storage, plus a SwiftUI demo app
that consumes it.

## Scope

In scope:
- Biometric authentication (Face ID / Touch ID) via `LocalAuthentication`
- Secure token storage/retrieval via Keychain (`Security` framework, no
  third-party dependency)
- A mock authentication provider that simulates login and token refresh
  without any real network calls
- A SwiftUI demo app exercising the full login → biometric unlock → token
  refresh → logout flow

Out of scope (explicitly excluded per YAGNI):
- Real network/backend integration
- OAuth2/OIDC social login
- App Attest / DeviceCheck device integrity verification
- Multi-package modularization (single package is sufficient at this scope)

## Architecture

Single SPM package, `SecureAuthKit`, targeting iOS 16+. The package itself
has no SwiftUI/Combine dependency — it's plain Swift using async/await, so it
stays reusable outside SwiftUI contexts. The demo app wraps the package's
facade in an `ObservableObject` for SwiftUI binding.

```
SecureAuthKit/                      (SPM package)
  Package.swift
  Sources/SecureAuthKit/
    AuthSession.swift               (public facade)
    BiometricAuthenticator.swift
    SecureTokenStore.swift
    MockAuthProvider.swift
    Models/AuthToken.swift
    Models/AuthState.swift
    Models/AuthError.swift
  Tests/SecureAuthKitTests/
    SecureTokenStoreTests.swift
    MockAuthProviderTests.swift
    AuthSessionTests.swift

SecureAuthKitDemo/                   (SwiftUI app, local package dependency)
  SecureAuthKitDemoApp.swift
  ViewModels/AuthViewModel.swift
  Views/LoginView.swift
  Views/BiometricLockView.swift
  Views/HomeView.swift
```

## Components

### `BiometricAuthenticator`
Wraps `LAContext`. Public surface:
```swift
protocol BiometricAuthenticating {
    func canAuthenticate() -> Bool
    func authenticate(reason: String) async throws -> Bool
}
```
Abstracted behind a protocol so `AuthSession` can be tested with a fake
implementation, since `LAContext`'s real biometric prompt cannot be exercised
in unit tests.

### `SecureTokenStore`
Wraps Keychain access directly via the `Security` framework (no third-party
dependency). Stores a single `AuthToken` (Codable) under a fixed service/
account key, with accessibility `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`.
Public surface:
```swift
protocol TokenStoring {
    func save(_ token: AuthToken) throws
    func load() throws -> AuthToken?
    func clear() throws
}
```

### `MockAuthProvider`
Simulates a remote auth server with artificial network delay (e.g. via
`Task.sleep`). Public surface:
```swift
protocol AuthProviding {
    func login(username: String, password: String) async throws -> AuthToken
    func refresh(refreshToken: String) async throws -> AuthToken
}
```
Fixed valid credentials for the demo (documented in code comments, e.g.
`demo` / `password123`). Invalid credentials throw `AuthError.invalidCredentials`.
Refresh with an unrecognized/expired refresh token throws
`AuthError.tokenExpired`.

### `AuthSession`
The public facade, composed of the three components above via constructor
injection (defaults to the real implementations; tests inject fakes).
```swift
public actor AuthSession {
    public init(
        authProvider: AuthProviding = MockAuthProvider(),
        tokenStore: TokenStoring = SecureTokenStore(),
        biometricAuthenticator: BiometricAuthenticating = BiometricAuthenticator()
    )

    public func signIn(username: String, password: String) async throws
    public func unlockWithBiometrics() async throws
    public func signOut() async
    public func currentToken() async -> AuthToken?
    public func refreshTokenIfNeeded() async throws

    public var stateStream: AsyncStream<AuthState> { get }
}
```

### `AuthError`
```swift
public enum AuthError: Error, LocalizedError {
    case invalidCredentials
    case biometryNotAvailable
    case biometryFailed
    case tokenExpired
    case noStoredToken
    case keychainError(OSStatus)
}
```
Each case has a `LocalizedError.errorDescription` for direct display in the
demo app's alerts.

### `AuthState`
```swift
public enum AuthState: Equatable {
    case loggedOut
    case lockedBiometric   // token exists but not yet unlocked this launch
    case authenticated(AuthToken)
}
```

## Data Flow

1. **First launch, no stored token**: `AuthSession` state is `.loggedOut` →
   demo app shows `LoginView` → on submit, `signIn` calls `MockAuthProvider`,
   saves the resulting `AuthToken` via `SecureTokenStore`, state becomes
   `.authenticated`.
2. **Relaunch with a stored token**: `AuthSession` initializes state as
   `.lockedBiometric` → demo app shows `BiometricLockView` → on unlock,
   `unlockWithBiometrics` reads the stored token (no server call) and moves
   state to `.authenticated`.
3. **Token expiry**: `AuthSession` checks the token's expiry timestamp on
   `currentToken()`/`refreshTokenIfNeeded()` calls; if expired, calls
   `MockAuthProvider.refresh` and re-saves via `SecureTokenStore`. The demo
   app also exposes a manual "Refresh Token" button on `HomeView`.
4. **Sign out**: `signOut` clears the Keychain entry and resets state to
   `.loggedOut`.

## Error Handling

- All thrown `AuthError`s propagate to the demo app's `AuthViewModel`, which
  surfaces them as SwiftUI alerts with the error's `errorDescription`.
- `BiometricAuthenticator.canAuthenticate()` is checked before attempting a
  prompt; if biometrics are unavailable (e.g. not enrolled, no passcode set),
  the demo app shows a non-fatal explanatory message instead of attempting
  the prompt.
- Keychain failures (rare, e.g. `errSecInteractionNotAllowed`) surface as
  `AuthError.keychainError` with the underlying `OSStatus` for debugging.

## Testing

- `SecureTokenStoreTests`: save → load → clear round trip against the real
  Keychain (using a dedicated test service identifier to avoid collisions).
- `MockAuthProviderTests`: valid login, invalid credentials, valid refresh,
  invalid/expired refresh token.
- `AuthSessionTests`: full orchestration using fake `AuthProviding`,
  `TokenStoring`, and `BiometricAuthenticating` implementations — covers
  sign-in, biometric unlock, token expiry triggering auto-refresh, and
  sign-out state transitions.
- `BiometricAuthenticator`'s real `LAContext` integration is not unit tested
  (framework limitation); this is documented in the test file and verified
  manually on-device/simulator instead.

## Demo App

SwiftUI, local Swift Package dependency on `SecureAuthKit`. `AuthViewModel`
wraps `AuthSession`, subscribing to `stateStream` and republishing as
`@Published var state: AuthState` for view binding.

Views:
- `LoginView` — username/password fields (pre-filled hint showing the mock
  credentials), submit button, error alert.
- `BiometricLockView` — shown when state is `.lockedBiometric`; prompts
  biometric unlock automatically on appear with a manual retry button.
- `HomeView` — shows decoded token info (subject, expiry countdown), "Refresh
  Token" and "Sign Out" buttons.
