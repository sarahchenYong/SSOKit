//
//  SSOModels.swift
//  SSOKit
//
//  Value types shared across the kit: the token payload handed to the host
//  app after a successful sign-in, and the typed error surface.
//

import Foundation

/// The tokens issued by the identity provider after a successful sign-in.
///
/// This is what a host app receives from `SSOClient.signIn` and what the
/// `SSOTokenStore` persists between launches.
public struct SSOTokenSet: Codable, Equatable {

    /// OAuth access token (send to APIs that accept the IdP's tokens).
    public let accessToken: String

    /// OIDC ID token (JWT carrying the user's identity claims) — the usual
    /// input for a backend token-exchange endpoint.
    public let idToken: String?

    /// Absolute expiry of `accessToken`, when known.
    public let expiresOn: Date?

    /// Signed-in account identifier (UPN / email), when known.
    public let username: String?

    /// Scopes actually granted.
    public let scopes: [String]

    public init(accessToken: String,
                idToken: String? = nil,
                expiresOn: Date? = nil,
                username: String? = nil,
                scopes: [String] = []) {
        self.accessToken = accessToken
        self.idToken = idToken
        self.expiresOn = expiresOn
        self.username = username
        self.scopes = scopes
    }

    /// `true` when the access token's expiry has passed (unknown expiry
    /// counts as not expired — the provider will reject it server-side).
    public var isExpired: Bool {
        guard let expiresOn else { return false }
        return expiresOn <= Date()
    }

    /// Seconds until expiry, when known.
    public var expiresIn: Int? {
        expiresOn.map { Int($0.timeIntervalSinceNow) }
    }

    /// Granted scopes as a single space-separated string.
    public var scope: String {
        scopes.joined(separator: " ")
    }
}

/// Errors surfaced by `SSOClient` and `SSOAuthProviding` implementations.
public enum SSOError: Error, Equatable {

    /// SSO is turned off in the configuration.
    case disabled

    /// The configuration still contains placeholder / empty credentials.
    case notConfigured

    /// The user dismissed the sign-in UI.
    case cancelled

    /// A silent renewal needs the user to sign in interactively again.
    case interactionRequired

    /// The identity provider rejected the sign-in.
    case authorizationFailed(String)

    /// Token renewal / exchange failed.
    case tokenExchangeFailed(String)

    /// Networking or decoding failure.
    case network(String)
}

extension SSOError: LocalizedError {

    public var errorDescription: String? { localizedDescription }

    public var localizedDescription: String {
        switch self {
        case .disabled:
            return "Single Sign-On is not enabled."
        case .notConfigured:
            return "Single Sign-On is not yet available. The integration is being configured."
        case .cancelled:
            return "Sign-in was cancelled."
        case .interactionRequired:
            return "Your session has expired. Please sign in again."
        case .authorizationFailed(let detail):
            return "Sign-in failed. \(detail)"
        case .tokenExchangeFailed(let detail):
            return "Could not complete sign-in. \(detail)"
        case .network(let detail):
            return detail
        }
    }
}

/// Lifecycle notifications emitted by `SSOClient` — a hook for host apps to
/// mirror state (analytics, app-level storage, UI refresh) without subclassing.
public enum SSOEvent {
    case signedIn(SSOTokenSet)
    case tokenRenewed(SSOTokenSet)
    case signedOut
    case failed(SSOError)
}
