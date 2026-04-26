import Foundation

/// App-wide configuration. Update these values before building.
enum Config {
    /// Base URL of your `deno-foundation` backend.
    static let baseURL = URL(string: "https://myapp.deno.dev")!

    /// Apple bundle ID — must match `APPLE_CLIENT_ID` set on the server for
    /// native Sign in with Apple to work (Apple uses the bundle ID as `aud`).
    static let bundleID = "com.example.myapp"
}
