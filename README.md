# swift-template

SwiftUI iOS app template that pairs with [`deno-template`](https://github.com/mac9sb/deno-template). Built on [`swift-foundation`](https://github.com/mac9sb/swift-foundation) for typed API access, session management, and auth.

**Minimum deployment target**: iOS 17

## What's included

- Sign in with Apple (uses `SignInWithAppleButton` — App Store compliant)
- Passkey login via `ASAuthorizationController` wrapped in Swift concurrency
- Magic link: sends the sign-in email, shows a "check your inbox" state
- `SessionStore` — `@Observable` auth state injected at the app root
- `HomeView` — basic signed-in screen with sign-out
- `Config.swift` — single place for `baseURL` and `bundleID`

## Development setup

### Prerequisites

- Xcode 16+
- [`xcodegen`](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`
- A running instance of [`deno-template`](https://github.com/mac9sb/deno-template) (or your Deno app)

### Steps

```bash
git clone https://github.com/mac9sb/swift-template MyApp
cd MyApp
xcodegen generate          # creates MyApp.xcodeproj
open MyApp.xcodeproj
```

1. In **Xcode → Signing & Capabilities**, select your team and let Xcode manage signing.
2. Update `Config.swift` — set `baseURL` to your backend URL and `bundleID` to your bundle identifier.
3. Set your bundle identifier in `project.yml` (`PRODUCT_BUNDLE_IDENTIFIER`) to match `Config.bundleID`.
4. Run on a real device or simulator.

**Local backend**: set `Config.baseURL` to `http://localhost:8000` while developing against a local `deno task dev` instance. Passkeys and Sign in with Apple require specific setup (see below).

**Magic links in development**: the backend emails a sign-in link. You can tap the link in Mail on a simulator, or copy the token from the server terminal and paste it into `<BASE_URL>/auth/verify?token=...` in Safari.

**Passkeys in development**: passkeys work on a real device and in Simulator when the backend URL is `localhost`. They require HTTPS in production.

**Sign in with Apple in development**: works on real devices and Simulator with any Apple ID. No additional configuration needed for testing — Apple issues real tokens in development.

## Configuration

| File | What to change |
|---|---|
| `Config.swift` | `baseURL` and `bundleID` |
| `project.yml` | `PRODUCT_BUNDLE_IDENTIFIER`, `name`, `bundleIdPrefix` |
| `Sources/App/MyApp.swift` | App struct name (match the `name` in `project.yml`) |

## Production checklist

- [ ] Update `Config.baseURL` to your production Deno Deploy URL
- [ ] Set `Config.bundleID` to your registered bundle identifier
- [ ] In Xcode, add the **Sign in with Apple** capability (Signing & Capabilities tab)
- [ ] In Xcode, add the **Associated Domains** capability with `webcredentials:<your-domain>` — this enables passkeys to work across your web and native app under the same domain
- [ ] On your Deno backend, serve `/.well-known/apple-app-site-association` with the associated domains JSON pointing to your bundle ID
- [ ] Set `APPLE_CLIENT_ID` on the server to your **bundle ID** (not the Services ID used for web — Apple uses the bundle ID as `aud` for native identity tokens)
- [ ] Archive and upload to App Store Connect with `xcodebuild archive`
