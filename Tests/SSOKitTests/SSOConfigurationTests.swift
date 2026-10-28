import XCTest
@testable import SSOKit

final class SSOConfigurationTests: XCTestCase {

    func testPlaceholderIsNotConfigured() {
        let config = SSOConfiguration(clientID: "REPLACE_ME_CLIENT_ID",
                                      tenantID: "00000000-0000-0000-0000-000000000000")
        XCTAssertFalse(config.isConfigured)
    }

    func testRealValuesAreConfigured() {
        let config = SSOConfiguration(clientID: "11111111-2222-3333-4444-555555555555",
                                      tenantID: "00000000-0000-0000-0000-000000000000")
        XCTAssertTrue(config.isConfigured)
    }

    func testAuthorityIsDerivedFromTenant() {
        let config = SSOConfiguration(clientID: "id", tenantID: "tenant-guid")
        XCTAssertEqual(config.resolvedAuthority?.absoluteString,
                       "https://login.microsoftonline.com/tenant-guid")
    }

    func testReservedScopesAreStripped() {
        let config = SSOConfiguration(clientID: "id", tenantID: "tenant",
                                      scopes: ["openid", "User.Read", "profile"])
        XCTAssertEqual(config.resolvedScopes, ["User.Read"])
    }

    func testAllReservedScopesFallBackToUserRead() {
        let config = SSOConfiguration(clientID: "id", tenantID: "tenant",
                                      scopes: ["openid", "email"])
        XCTAssertEqual(config.resolvedScopes, ["User.Read"])
    }

    func testTokenSetExpiry() {
        let expired = SSOTokenSet(accessToken: "t", expiresOn: Date(timeIntervalSinceNow: -60))
        let valid = SSOTokenSet(accessToken: "t", expiresOn: Date(timeIntervalSinceNow: 600))
        let unknown = SSOTokenSet(accessToken: "t")
        XCTAssertTrue(expired.isExpired)
        XCTAssertFalse(valid.isExpired)
        XCTAssertFalse(unknown.isExpired)
    }

    func testInMemoryStoreRoundTrip() {
        let store = InMemorySSOTokenStore()
        let tokens = SSOTokenSet(accessToken: "abc", idToken: "def",
                                 username: "user@example.com", scopes: ["User.Read"])
        store.save(tokens)
        XCTAssertEqual(store.load(), tokens)
        store.clear()
        XCTAssertNil(store.load())
    }
}
