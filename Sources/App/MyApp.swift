import SwiftUI
import FoundationKit

@main
struct MyApp: App {
    private let client = APIClient(baseURL: Config.baseURL)
    @State private var session: SessionStore

    init() {
        let client = APIClient(baseURL: Config.baseURL)
        _session = State(initialValue: SessionStore(client: client))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(session)
                .task { await session.refresh() }
        }
    }
}
