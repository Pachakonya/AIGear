import SwiftUI

struct RootView: View {
    @AppStorage("hasSeenLaunchScreen") var hasSeenLaunchScreen: Bool = false
    @StateObject private var authService = AuthService.shared

    var body: some View {
        NavigationView {
            if !hasSeenLaunchScreen {
                LaunchScreenView()
            } else if !authService.isAuthenticated {
                AuthGate() // Replace with your actual auth view
            } else {
                MainTabView()
            }
        }
        
//        The launch Screen Would pop up now
        .onAppear {
            hasSeenLaunchScreen = false // Always show launch screen on app start
        }
    }
}
