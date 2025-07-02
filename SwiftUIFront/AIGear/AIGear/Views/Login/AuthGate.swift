import SwiftUI

struct AuthGate: View {
    @StateObject private var authService = AuthService.shared

    var body: some View {
        if authService.isAuthenticated {
            MainTabView() // Replace with your main app view
        } else {
            SignUpOrSignInView()
        }
    }
}

