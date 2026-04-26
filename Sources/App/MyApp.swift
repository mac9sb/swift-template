import SwiftUI
import FoundationKit

@main
struct MyApp: App {
    private let client: APIClient
    @State private var session: SessionStore

    init() {
        let client = APIClient(baseURL: Config.baseURL)
        self.client = client
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
