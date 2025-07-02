import SwiftUI

struct RootView: View {
    @AppStorage("hasSeenLaunchScreen") var hasSeenLaunchScreen: Bool = false
    @AppStorage("isSignedIn") var isSignedIn: Bool = false

    var body: some View {
        NavigationView {
            if !hasSeenLaunchScreen {
                LaunchScreenView()
            } else if !isSignedIn {
                AuthGate() // Replace with your actual auth view
            } else {
                MainTabView()
            }
        }
    }
}
