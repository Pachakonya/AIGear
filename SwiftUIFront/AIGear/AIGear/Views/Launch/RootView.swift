import SwiftUI

struct RootView: View {
    @AppStorage("hasSeenLaunchScreen") var hasSeenLaunchScreen: Bool = false
    @StateObject private var authService = AuthService.shared
    @State private var isCheckingProfile = false

    var body: some View {
        NavigationView {
            if !hasSeenLaunchScreen {
                LaunchScreenView()
            } else if !authService.isAuthenticated {
                AuthGate()
            } else if isCheckingProfile {
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
        }
        .onAppear {
            // Check profile completion when authenticated user appears
            if authService.isAuthenticated && authService.currentUser != nil {
                checkProfileCompletion()
            }
        }
        .onChange(of: authService.isAuthenticated) { isAuth in
            if isAuth {
                checkProfileCompletion()
            }
        }
    }
    
    private func checkProfileCompletion() {
        isCheckingProfile = true
        authService.refreshCurrentUser { success in
            isCheckingProfile = false
        }
    }
}
