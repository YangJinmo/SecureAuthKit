import Foundation
import SecureAuthKit

@MainActor
final class AuthViewModel: ObservableObject {
    @Published private(set) var state: AuthState = .loggedOut
    @Published var errorMessage: String?

    private let session: AuthSession
    private var observationTask: Task<Void, Never>?

    init(session: AuthSession? = nil) {
        self.session = session ?? AuthSession()
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
