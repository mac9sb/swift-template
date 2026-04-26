import SwiftUI
import FoundationKit

struct ContentView: View {
    @Environment(SessionStore.self) private var session

    var body: some View {
        Group {
            if session.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if session.isAuthenticated {
                HomeView()
            } else {
                AuthView()
            }
        }
        .animation(.easeInOut(duration: 0.2), value: session.isAuthenticated)
    }
}
