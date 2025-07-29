import SwiftUI

struct AuthGate: View {
    @StateObject private var authService = AuthService.shared
    @State private var isCheckingProfile = false

    var body: some View {
        if authService.isAuthenticated {
            if isCheckingProfile {
                // Show loading while checking profile
                VStack {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Loading your profile...")
                        .font(.headline)
                        .padding(.top)
                }
            } else if let user = authService.currentUser, !user.isProfileCompleted {
                ProfileSetupView(onComplete: {
                    // Refresh user data after profile completion
                    authService.refreshCurrentUser { _ in
                        // Navigation will automatically update when user data changes
                    }
                })
            } else {
                MainTabView()
            }
        } else {
            SignUpOrSignInView()
        }
    }
}

