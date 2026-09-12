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
