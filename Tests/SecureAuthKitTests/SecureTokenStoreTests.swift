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
