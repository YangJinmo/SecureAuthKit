/// A protocol for storing and retrieving authentication tokens securely.
public protocol TokenStoring: Sendable {
    /// Saves an authentication token.
    /// - Parameter token: The token to save.
    /// - Throws: An error if the save operation fails.
    func save(_ token: AuthToken) throws

    /// Loads the stored authentication token.
    /// - Returns: The stored token, or nil if no token is currently stored.
    /// - Throws: An error if the load operation fails.
    func load() throws -> AuthToken?

    /// Clears the stored authentication token.
    /// - Throws: An error if the clear operation fails.
    func clear() throws
}
