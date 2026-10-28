//
//  SSOTokenStore.swift
//  SSOKit
//
//  Pluggable persistence for the issued tokens. The default is a Keychain
//  store; hosts can swap in their own (UserDefaults, database, none) by
//  conforming to `SSOTokenStore`.
//

import Foundation
import Security

/// Where `SSOClient` keeps the last-issued token set between launches.
public protocol SSOTokenStore {
    func save(_ tokens: SSOTokenSet)
    func load() -> SSOTokenSet?
    func clear()
}

/// Default store: a single generic-password Keychain item holding the
/// JSON-encoded `SSOTokenSet`. Device-only, available after first unlock.
public final class KeychainSSOTokenStore: SSOTokenStore {

    private let service: String
    private let account: String

    /// - Parameters:
    ///   - service: Keychain service namespace; keep the default unless the
    ///     host runs several independent SSO clients.
    ///   - account: item discriminator; defaults to the app's bundle id.
    public init(service: String = "com.ssokit.tokens",
                account: String = Bundle.main.bundleIdentifier ?? "ssokit") {
        self.service = service
        self.account = account
    }

    private var baseQuery: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }

    public func save(_ tokens: SSOTokenSet) {
        guard let data = try? JSONEncoder().encode(tokens) else { return }

        var query = baseQuery
        SecItemDelete(query as CFDictionary)

        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(query as CFDictionary, nil)
    }

    public func load() -> SSOTokenSet? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else {
            return nil
        }
        return try? JSONDecoder().decode(SSOTokenSet.self, from: data)
    }

    public func clear() {
        SecItemDelete(baseQuery as CFDictionary)
    }
}

/// Ephemeral store for unit tests, previews, or hosts that keep tokens
/// exclusively in their own storage via `SSOClient.onEvent`.
public final class InMemorySSOTokenStore: SSOTokenStore {

    private var tokens: SSOTokenSet?

    public init() {}

    public func save(_ tokens: SSOTokenSet) { self.tokens = tokens }
    public func load() -> SSOTokenSet? { tokens }
    public func clear() { tokens = nil }
}
