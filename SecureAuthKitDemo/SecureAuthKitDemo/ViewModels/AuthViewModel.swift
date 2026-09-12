import Foundation
import SecureAuthKit

@MainActor
final class AuthViewModel: ObservableObject {
    @Published private(set) var state: AuthState
    @Published var errorMessage: String?

    private let session: AuthSession
    private var observationTask: Task<Void, Never>?

    init(session: AuthSession? = nil) {
        let session = session ?? AuthSession()
        self.session = session
        // Seed synchronously so a relaunch with a stored token renders the lock screen on the
        // first frame instead of flashing the login screen until the stream delivers the state.
        self.state = session.currentState

        // The stream is captured before the task so the task never holds a strong `self`:
        // `self` is re-checked per iteration and released at every suspension point.
        let stream = session.stateStream
        observationTask = Task { [weak self] in
            for await newState in stream {
                self?.state = newState
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
        do {
            try session.signOut()
            errorMessage = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Something went wrong."
        }
    }
}
