//
//  EntraMSALProvider.swift
//  SSOKit
//
//  Microsoft Entra ID sign-in via MSAL, brokered through the Microsoft
//  Authenticator app: interactive sign-in hands off to Authenticator (when
//  installed) using the `msauth.<bundle id>://auth` redirect and returns with
//  the issued tokens. Without Authenticator, MSAL falls back to the system
//  web session automatically.
//
//  Host-app plumbing this relies on (see the SSOKit README):
//    • Info.plist  — CFBundleURLTypes scheme `msauth.$(PRODUCT_BUNDLE_IDENTIFIER)`
//                    and LSApplicationQueriesSchemes msauthv2 / msauthv3.
//    • Scene/App delegate — forwards the callback URL to
//                    `SSOClient.handleRedirect(_:sourceApplication:)`.
//

import UIKit
import MSAL

/// The built-in `SSOAuthProviding` brick for Microsoft Entra ID.
public final class EntraMSALProvider: SSOAuthProviding {
    private let configuration: SSOConfiguration

    public init(configuration: SSOConfiguration) {
        self.configuration = configuration
    }

    // MARK: - MSAL application

    private func makeApplication() throws -> MSALPublicClientApplication {
        guard let authorityURL = configuration.resolvedAuthority else {
            throw SSOError.notConfigured
        }
        let authority = try MSALAADAuthority(url: authorityURL)

        let config = MSALPublicClientApplicationConfig(
            clientId: configuration.clientID,
            redirectUri: configuration.resolvedRedirectURI,
            authority: authority
        )
        // Keep the token cache in the app's own keychain group so no
        // keychain-sharing entitlement / provisioning change is required.
        // (Brokered sign-in through Authenticator is unaffected by this.)
        if let group = configuration.resolvedKeychainSharingGroup {
            config.cacheConfig.keychainSharingGroup = group
        }
        return try MSALPublicClientApplication(configuration: config)
    }

    // MARK: - SSOAuthProviding

    public func signIn(from presenter: UIViewController,
                       completion: @escaping (Result<SSOTokenSet, SSOError>) -> Void) {

        let application: MSALPublicClientApplication
        do {
            application = try makeApplication()
        } catch let error as SSOError {
            return completion(.failure(error))
        } catch {
            return completion(.failure(.authorizationFailed(error.localizedDescription)))
        }

        let webParameters = MSALWebviewParameters(authPresentationViewController: presenter)
        // `.default` is required for the Authenticator broker hand-off.
        webParameters.webviewType = .default

        let parameters = MSALInteractiveTokenParameters(
            scopes: configuration.resolvedScopes,
            webviewParameters: webParameters
        )
        parameters.promptType = .selectAccount

        application.acquireToken(with: parameters) { result, error in
            if let error = error {
                return completion(.failure(Self.map(error)))
            }
            guard let result = result else {
                return completion(.failure(.authorizationFailed("No result returned from sign-in.")))
            }
            completion(.success(Self.tokenSet(from: result)))
        }
    }

    public func acquireTokenSilent(
        scopes: [String],
        completion: @escaping (Result<String, SSOError>) -> Void
    ) {
        let application: MSALPublicClientApplication

        do {
            application = try makeApplication()
        } catch {
            return completion(
                .failure(
                    .tokenExchangeFailed("SSO is not configured.")
                )
            )
        }

        guard let account = (try? application.allAccounts())?.first else {
            return completion(.failure(.interactionRequired))
        }

        let parameters = MSALSilentTokenParameters(
            scopes: scopes,
            account: account
        )

        application.acquireTokenSilent(with: parameters) { result, error in
            if let error {
                return completion(.failure(Self.map(error)))
            }

            guard let result else {
                return completion(
                    .failure(
                        .tokenExchangeFailed(
                            "No API token returned."
                        )
                    )
                )
            }

            completion(.success(result.accessToken))
        }
    }
    
    public func renewToken(completion: @escaping (Result<SSOTokenSet, SSOError>) -> Void) {

        let application: MSALPublicClientApplication
        do {
            application = try makeApplication()
        } catch {
            return completion(.failure(.tokenExchangeFailed("SSO is not configured.")))
        }

        guard let account = (try? application.allAccounts())?.first else {
            return completion(.failure(.interactionRequired))
        }

        let parameters = MSALSilentTokenParameters(
            scopes: configuration.resolvedScopes,
            account: account
        )

        application.acquireTokenSilent(with: parameters) { result, error in
            if let error = error {
                return completion(.failure(Self.map(error)))
            }
            guard let result = result else {
                return completion(.failure(.tokenExchangeFailed("No result returned from token refresh.")))
            }
            completion(.success(Self.tokenSet(from: result)))
        }
    }

    public func signOut() throws {
        let application = try makeApplication()
        for account in (try? application.allAccounts()) ?? [] {
            try? application.remove(account)
        }
    }

    @discardableResult
    public func handleRedirect(_ url: URL, sourceApplication: String?) -> Bool {
        MSALPublicClientApplication.handleMSALResponse(
            url,
            sourceApplication: sourceApplication
        )
    }

    // MARK: - Mapping

    private static func tokenSet(from result: MSALResult) -> SSOTokenSet {
        SSOTokenSet(
            accessToken: result.accessToken,
            idToken: result.idToken,
            expiresOn: result.expiresOn,
            username: result.account.username,
            scopes: result.scopes
        )
    }

    private static func map(_ error: Error) -> SSOError {
        let nsError = error as NSError
        if nsError.domain == MSALErrorDomain {
            switch nsError.code {
            case MSALError.userCanceled.rawValue:
                return .cancelled
            case MSALError.interactionRequired.rawValue:
                return .interactionRequired
            default:
                break
            }
        }
        let detail = (nsError.userInfo[MSALErrorDescriptionKey] as? String)
            ?? nsError.localizedDescription
        return .authorizationFailed(detail)
    }
}
