import SwiftUI
import Clerk

struct AuthGate: View {
    @Environment(Clerk.self) private var clerk

    var body: some View {
        if clerk.user != nil {
            MainTabView() // Replace with your main app view
        } else {
            SignUpOrSignInView()
        }
    }
}

