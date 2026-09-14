import Foundation
import Security

/// A Keychain-backed implementation of the TokenStoring protocol.
/// Securely stores and retrieves authentication tokens using the system Keychain.
public final class SecureTokenStore: TokenStoring, Sendable {
    private let service: String
    private let account = "currentUser"

    /// Initializes a SecureTokenStore with the specified service identifier.
    /// - Parameter service: The Keychain service identifier. Defaults to "com.secureauthkit.tokenstore".
    public init(service: String = "com.secureauthkit.tokenstore") {
        self.service = service
    }

    /// Saves an authentication token to the Keychain.
    /// - Parameter token: The token to save.
    /// - Throws: AuthError.keychainError if the save operation fails.
    public func save(_ token: AuthToken) throws {
        let data = try JSONEncoder().encode(token)
        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        // Delete any existing item first
        SecItemDelete(baseQuery as CFDictionary)

        // Add the new item
        var attributes = baseQuery
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw AuthError.keychainError(status)
        }
    }

    /// Loads the stored authentication token from the Keychain.
    /// - Returns: The stored token, or nil if no token is currently stored.
    /// - Throws: AuthError.keychainError if the load operation fails (except when no item is found).
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

    /// Clears the stored authentication token from the Keychain.
    /// - Throws: AuthError.keychainError if the clear operation fails (except when no item exists).
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
