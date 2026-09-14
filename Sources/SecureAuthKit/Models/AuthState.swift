public enum AuthState: Equatable, Sendable {
    case loggedOut
    case lockedBiometric
    case authenticated(AuthToken)
}
