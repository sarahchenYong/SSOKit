//
//  SSOAuthProviding.swift
//  SSOKit
//
//  The identity-provider socket. `EntraMSALProvider` is the built-in brick;
//  a host (or a future SSOKit version) can plug in another IdP — Okta, Ping,
//  a mock for tests — by conforming to this protocol.
//

import UIKit

/// Abstraction over one identity provider's native SDK.
///
/// Completions may be invoked on any thread; `SSOClient` normalises delivery
/// to the main thread before the host app sees them.
public protocol SSOAuthProviding: AnyObject {

    func acquireTokenSilent(
        scopes: [String],
        completion: @escaping (Result<String, SSOError>) -> Void
    )
    
    /// Starts an interactive sign-in anchored to the given view controller.
    func signIn(from presenter: UIViewController,
                completion: @escaping (Result<SSOTokenSet, SSOError>) -> Void)

    /// Renews tokens silently from the provider's own cache/session.
    /// Fails with `.interactionRequired` when the user must sign in again.
    func renewToken(completion: @escaping (Result<SSOTokenSet, SSOError>) -> Void)

    /// Clears the provider-side account/session state.
    func signOut() throws

    /// Gives the provider a chance to consume a redirect URL delivered to the
    /// app (broker/web callback). Returns `true` when the URL was handled.
    @discardableResult
    func handleRedirect(_ url: URL, sourceApplication: String?) -> Bool
}
