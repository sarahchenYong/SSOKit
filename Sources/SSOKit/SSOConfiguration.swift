//
//  SSOConfiguration.swift
//  SSOKit
//
//  All the knobs a host app can turn, in one value type. Build it in code,
//  or load it from a bundled plist with per-environment sub-keys (see
//  `SSOConfiguration.fromPlist`).
//

import Foundation

/// Immutable configuration for one SSO client.
///
/// Sensible defaults are derived where possible: the authority URL from the
/// tenant, the redirect URI from the app's bundle identifier — so most apps
/// only need to supply `clientID` and `tenantID`.
public struct SSOConfiguration {

    /// Master switch. When `false`, `SSOClient.signIn` fails fast with
    /// `SSOError.disabled` instead of starting a broken flow.
    public var isEnabled: Bool

    /// Application (client) ID of the app registration in Microsoft Entra ID.
    public var clientID: String

    /// Directory (tenant) ID (GUID) or tenant domain, e.g. `contoso.onmicrosoft.com`.
    public var tenantID: String

    /// Full authority URL. Defaults to `https://login.microsoftonline.com/<tenantID>`.
    public var authority: URL?

    /// Broker redirect URI. Defaults to `msauth.<bundle id>://auth` — the MSAL
    /// format that must also be registered in Azure and declared in the app's
    /// `CFBundleURLTypes`.
    public var redirectURI: String?

    /// Resource scopes to request. Reserved OIDC scopes (openid, profile,
    /// email, offline_access) are stripped automatically — MSAL adds them
    /// itself and rejects explicit duplicates.
    public var scopes: [String]

    /// Optional resource scopes a host app can use after sign-in to acquire a
    /// token for its own backend API. They do not change the sign-in request.
    public var accessTokenScopes: [String]

    /// Keychain group for MSAL's token cache. Defaults to the app's own bundle
    /// id so no keychain-sharing entitlement is required.
    public var keychainSharingGroup: String?

    public init(isEnabled: Bool = true,
                clientID: String,
                tenantID: String,
                authority: URL? = nil,
                redirectURI: String? = nil,
                scopes: [String] = ["User.Read"],
                keychainSharingGroup: String? = nil,
                accessTokenScopes: [String] = []) {
        self.isEnabled = isEnabled
        self.clientID = clientID
        self.tenantID = tenantID
        self.authority = authority
        self.redirectURI = redirectURI
        self.scopes = scopes
        self.keychainSharingGroup = keychainSharingGroup
        self.accessTokenScopes = accessTokenScopes
    }

    // MARK: - Validation & derived values

    /// `true` once the minimum credentials are present (non-empty, no
    /// REPLACE_ME placeholders). `SSOClient` refuses to start otherwise.
    public var isConfigured: Bool {
        !clientID.isEmpty && !tenantID.isEmpty
            && !clientID.contains("REPLACE_ME")
            && !tenantID.contains("REPLACE_ME")
    }

    public var resolvedAuthority: URL? {
        authority ?? URL(string: "https://login.microsoftonline.com/\(tenantID)")
    }

    public var resolvedRedirectURI: String {
        redirectURI ?? "msauth.\(Bundle.main.bundleIdentifier ?? "")://auth"
    }

    public var resolvedKeychainSharingGroup: String? {
        keychainSharingGroup ?? Bundle.main.bundleIdentifier
    }

    /// Scopes with the reserved OIDC set removed; never empty.
    public var resolvedScopes: [String] {
        let reserved: Set<String> = ["openid", "profile", "email", "offline_access"]
        let filtered = scopes.filter { !reserved.contains($0.lowercased()) }
        return filtered.isEmpty ? ["User.Read"] : filtered
    }
}

// MARK: - Plist loading

extension SSOConfiguration {

    /// Loads configuration from a bundled plist, e.g. `SSOConfig.plist`:
    ///
    /// ```
    /// Enabled            : Bool
    /// Entra
    ///   ClientID         : String — or a Dict of <environmentKey>: String
    ///   TenantID         : String — or a Dict of <environmentKey>: String
    ///   Authority        : String (optional override)
    ///   RedirectURI      : String (optional override)
    ///   Scopes           : [String] (optional)
    ///   AccessTokenScopes: Dict of <environmentKey>: [String] (optional)
    /// ```
    ///
    /// Keys that can differ per build flavour (`ClientID`, `TenantID`,
    /// `AccessTokenScopes`) may be
    /// plain strings or dictionaries keyed by `environmentKey`
    /// (e.g. "Dev" / "QA" / "Live") — pass the running flavour's key.
    ///
    /// - Returns: `nil` when the plist is missing or unreadable.
    public static func fromPlist(named name: String,
                                 in bundle: Bundle = .main,
                                 environmentKey: String) -> SSOConfiguration? {

        guard let url = bundle.url(forResource: name, withExtension: "plist"),
              let root = NSDictionary(contentsOf: url) as? [String: Any] else {
            return nil
        }

        let entra = root["Entra"] as? [String: Any] ?? [:]

        func environmentValue(_ key: String) -> String? {
            if let plain = entra[key] as? String { return plain }
            if let perEnvironment = entra[key] as? [String: Any] {
                return perEnvironment[environmentKey] as? String
            }
            return nil
        }

        func environmentScopes(_ key: String) -> [String] {
            if let plain = entra[key] as? [String] { return plain }
            if let perEnvironment = entra[key] as? [String: Any] {
                return perEnvironment[environmentKey] as? [String] ?? ["User.Read"]
            }
            return []
        }

        return SSOConfiguration(
            isEnabled: root["Enabled"] as? Bool ?? false,
            clientID: environmentValue("ClientID") ?? "",
            tenantID: environmentValue("TenantID") ?? "",
            authority: (entra["Authority"] as? String).flatMap(URL.init(string:)),
            redirectURI: entra["RedirectURI"] as? String,
            scopes: entra["Scopes"] as? [String] ?? ["User.Read"],
            accessTokenScopes: environmentScopes("AccessTokenScopes")
        )
    }
}
