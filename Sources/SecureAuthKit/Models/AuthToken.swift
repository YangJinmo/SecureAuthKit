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

    public var isExpired: Bool {
        Date() >= expiresAt
    }
}
