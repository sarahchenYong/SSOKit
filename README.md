# SSOKit

Microsoft Entra ID Single Sign-On for iOS apps, in a box. Wraps MSAL (brokered
through Microsoft Authenticator, with automatic web fallback) behind a small,
pluggable API.

```
┌─────────────────────────────────────────────────────────────┐
│                         SSOClient                           │
│  guards config · persists tokens · main-thread completions  │
└───────────────┬──────────────────────────┬──────────────────┘
                │                          │
      SSOAuthProviding              SSOTokenStore
      (EntraMSALProvider,           (KeychainSSOTokenStore,
       your own IdP, a mock)         InMemory, your own)
```

Every brick is swappable: the identity provider, the token store, the config
source, and the UI button are independent. Use all of them or only `SSOClient`.

## Integration checklist (per app)

### 1. Add the package

Add `https://github.com/sarahchenYong/SSOKit.git` under
*File → Add Package Dependencies…*, using version **1.0.0** or later.
MSAL comes in automatically via SPM — **do not** also add the MSAL CocoaPod.

### 2. Info.plist (copy-paste, identical in every app)

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLName</key>
        <string>$(PRODUCT_BUNDLE_IDENTIFIER).sso</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>msauth.$(PRODUCT_BUNDLE_IDENTIFIER)</string>
        </array>
    </dict>
</array>
<key>LSApplicationQueriesSchemes</key>
<array>
    <string>msauthv2</string>
    <string>msauthv3</string>
</array>
```

### 3. Azure app registration (ask IT — the only non-code step)

Per app **and** per environment:
- iOS/macOS platform with redirect URI `msauth.<bundle id>://auth`
- Delegated `User.Read` permission (admin consent)
- If "Assignment required" is on, test users must be in the app's security group

### 4. Create a client

```swift
import SSOKit

let sso = SSOClient(configuration: SSOConfiguration(
    clientID: "<app registration client id>",
    tenantID: "<directory tenant id>"
))
```

Or load from a bundled plist with per-environment client IDs
(`Entra → ClientID → Dev/QA/Live` sub-keys):

```swift
let config = SSOConfiguration.fromPlist(named: "SSOConfig", environmentKey: "Dev")
let sso = SSOClient(configuration: config ?? SSOConfiguration(isEnabled: false, clientID: "", tenantID: ""))
```

### 5. Forward the redirect (scene delegate)

```swift
func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    guard let context = URLContexts.first else { return }
    sso.handleRedirect(context.url, sourceApplication: context.options.sourceApplication)
}
```

### 6. Sign in

```swift
sso.signIn(from: viewController) { result in
    switch result {
    case .success(let tokens):
        // tokens.accessToken / tokens.idToken / tokens.username
        // → exchange with YOUR backend for an app session
    case .failure(.cancelled):
        break
    case .failure(let error):
        show(error.localizedDescription)
    }
}
```

## Everyday API

| Call | Purpose |
|---|---|
| `sso.signIn(from:completion:)` | Interactive sign-in (broker → web fallback) |
| `sso.validAccessToken(completion:)` | Valid token now, silently renewed if needed |
| `sso.signOut()` | Clear provider account + stored tokens |
| `sso.isSignedIn` / `currentAccessToken` / `signedInEmail` | Session state |
| `sso.onEvent = { … }` | Mirror lifecycle events (analytics, app storage) |
| `OutlookSSOButton()` | Ready-made "SSO Login" button (all design tokens overridable) |

## Extending (the lego part)

- **Another IdP** — conform to `SSOAuthProviding`, pass it to
  `SSOClient(configuration:provider:)`. Nothing else changes.
- **Different persistence** — conform to `SSOTokenStore`
  (`KeychainSSOTokenStore` is the default; `InMemorySSOTokenStore` for tests).
- **App-side state mirroring** — subscribe to `onEvent` instead of wrapping
  the client.
- **Unit testing hosts** — inject a mock `SSOAuthProviding`; no MSAL, no
  network, no UI.

## Gotchas already handled

- Reserved OIDC scopes (`openid`, `profile`, `email`, `offline_access`) are
  stripped automatically — MSAL adds them itself and rejects duplicates.
- Placeholder credentials (`REPLACE_ME…`) short-circuit with a friendly
  `.notConfigured` error instead of a broken flow.
- MSAL's token cache stays in the app's own keychain group — no
  keychain-sharing entitlement needed.
- Completions always arrive on the main thread.
