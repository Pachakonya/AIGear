import SwiftUI
import Clerk

@main
struct AIGearApp: App {
    @State private var clerk = Clerk.shared

    var body: some Scene {
        WindowGroup {
            ZStack {
                if clerk.isLoaded {
                    AuthGate()
                } else {
                    ProgressView("Loading...")
                }
            }
            .environment(clerk)
            .task {
                clerk.configure(publishableKey: "pk_test_c2ltcGxlLWFhcmR2YXJrLTk5LmNsZXJrLmFjY291bnRzLmRldiQ")
                try? await clerk.load()
            }
        }
    }
}
