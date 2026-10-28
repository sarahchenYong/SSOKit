//
//  SSOClient.swift
//  SSOKit
//
//  The facade — the only type a host app needs to talk to.
//
//  ┌─────────────────────────────────────────────────────────────┐
//  │                         SSOClient                           │
//  │  guards config · persists tokens · main-thread completions  │
//  └───────────────┬──────────────────────────┬──────────────────┘
//                  │                          │
//        SSOAuthProviding             SSOTokenStore
//        (EntraMSALProvider,          (KeychainSSOTokenStore,
//         your own IdP, a mock)        InMemory, your own)
//
//  Minimal usage:
//
//      let sso = SSOClient(configuration: .init(clientID: "…", tenantID: "…"))
//      sso.signIn(from: viewController) { result in … }
//
//      // Scene delegate:
//      sso.handleRedirect(url, sourceApplication: source)
//

import UIKit

public final class SSOClient {

    // MARK: - Bricks

    public let configuration: SSOConfiguration
    private let provider: SSOAuthProviding
    private let tokenStore: SSOTokenStore

    /// Optional observability hook: fired (on the main thread) for every
    /// lifecycle change, so hosts can mirror state without wrapping the client.
    public var onEvent: ((SSOEvent) -> Void)?

    /// - Parameters:
    ///   - configuration: the environment's credentials and switches.
    ///   - provider: identity-provider brick; defaults to Microsoft Entra ID
    ///     via MSAL (`EntraMSALProvider`).
    ///   - tokenStore: persistence brick; defaults to the Keychain.
    public init(configuration: SSOConfiguration,
                provider: SSOAuthProviding? = nil,
                tokenStore: SSOTokenStore = KeychainSSOTokenStore()) {
        self.configuration = configuration
        self.provider = provider ?? EntraMSALProvider(configuration: configuration)
        self.tokenStore = tokenStore
    }

    // MARK: - State

    public var isEnabled: Bool { configuration.isEnabled }

    public var isConfigured: Bool { configuration.isConfigured }

    /// Whether the SSO entry point should be offered at all.
    public var isAvailable: Bool { isEnabled }

    /// The stored token set from the last successful sign-in/renewal (if any),
    /// regardless of expiry.
    public var currentTokens: SSOTokenSet? { tokenStore.load() }

    /// A stored, still-valid access token — or `nil` when absent/expired.
    public var currentAccessToken: String? {
        guard let tokens = currentTokens, !tokens.isExpired else { return nil }
        return tokens.accessToken
    }

    public var signedInEmail: String? { currentTokens?.username }

    public var isSignedIn: Bool { currentAccessToken != nil }

    // MARK: - Sign in

    /// Starts the interactive sign-in. With Microsoft Authenticator installed
    /// the flow is brokered through it; otherwise a system web session is
    /// presented. The completion is always called on the main thread.
    public func signIn(from presenter: UIViewController,
                       completion: @escaping (Result<SSOTokenSet, SSOError>) -> Void) {

        guard isEnabled else { return finish(.failure(.disabled), completion) }
        guard isConfigured else { return finish(.failure(.notConfigured), completion) }

        provider.signIn(from: presenter) { [weak self] result in
            guard let self = self else { return }

            if case .success(let tokens) = result {
                self.tokenStore.save(tokens)
            }
            self.finish(result, completion, success: SSOEvent.signedIn)
        }
    }

    // MARK: - Token renewal

    /// Returns a valid access token, renewing silently through the provider's
    /// cached account when the stored one is missing or expired.
    public func validAccessToken(completion: @escaping (Result<String, SSOError>) -> Void) {

        if let token = currentAccessToken {
            return DispatchQueue.main.async { completion(.success(token)) }
        }

        guard isEnabled, isConfigured else {
            return DispatchQueue.main.async { completion(.failure(.notConfigured)) }
        }

        provider.renewToken { [weak self] result in
            guard let self = self else { return }

            if case .success(let tokens) = result {
                self.tokenStore.save(tokens)
            }
            DispatchQueue.main.async {
                switch result {
                case .success(let tokens):
                    self.onEvent?(.tokenRenewed(tokens))
                    completion(.success(tokens.accessToken))
                case .failure(let error):
                    self.onEvent?(.failed(error))
                    completion(.failure(error))
                }
            }
        }
    }

    public func acquireTokenSilent(
        scopes: [String],
        completion: @escaping (Result<String, SSOError>) -> Void
    ) {
        guard isEnabled else {
            return DispatchQueue.main.async {
                completion(.failure(.disabled))
            }
        }

        guard isConfigured else {
            return DispatchQueue.main.async {
                completion(.failure(.notConfigured))
            }
        }

        provider.acquireTokenSilent(scopes: scopes) { [weak self] result in
            guard let self else { return }

            DispatchQueue.main.async {
                if case .failure(let error) = result {
                    self.onEvent?(.failed(error))
                }

                completion(result)
            }
        }
    }
    
    // MARK: - Sign out

    /// Clears the provider account and the stored tokens.
    public func signOut() {
        try? provider.signOut()
        tokenStore.clear()
        DispatchQueue.main.async { self.onEvent?(.signedOut) }
    }

    // MARK: - Redirect plumbing

    /// Forward `msauth.<bundle id>://auth` callbacks here from the scene/app
    /// delegate. Returns `true` when the URL belonged to an SSO flow.
    @discardableResult
    public func handleRedirect(_ url: URL, sourceApplication: String? = nil) -> Bool {
        provider.handleRedirect(url, sourceApplication: sourceApplication)
    }

    // MARK: - Helpers

    private func finish(_ result: Result<SSOTokenSet, SSOError>,
                        _ completion: @escaping (Result<SSOTokenSet, SSOError>) -> Void,
                        success event: ((SSOTokenSet) -> SSOEvent)? = nil) {
        DispatchQueue.main.async {
            switch result {
            case .success(let tokens):
                if let event { self.onEvent?(event(tokens)) }
            case .failure(let error):
                self.onEvent?(.failed(error))
            }
            completion(result)
        }
    }
    
}
