import SwiftUI

enum LaunchDestination: Hashable {
    case mainTab
    case auth
}

struct LaunchScreenView: View {
    @AppStorage("hasSeenLaunchScreen") var hasSeenLaunchScreen: Bool = false
    @AppStorage("isSignedIn") var isSignedIn: Bool = false
    @State private var path: [LaunchDestination] = []

    var body: some View {
        NavigationStack(path: $path) {
            GeometryReader { geo in
                ZStack {
                    // Background image
                    Image("launch_hiker")
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .scaleEffect(1.2)
                        .offset(y: 20)
                        .offset(x: 100)
                        .ignoresSafeArea()

                    VStack(alignment: .leading, spacing: 0) {
                        Spacer().frame(height: 100) // Push content down a bit from the top

                        // AI : GEAR logo and label
                        HStack(spacing: 8) {
                            Image("horse_icon")
                                .resizable()
                                .frame(width: 24, height: 24)
                            Text("AI : GEAR")
                                .font(.custom("DMMono-Regular", size: 20))
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.black)
                        .padding(.leading, 40)

                        // Headline
                        Text("The Better\nWay To Plan\nHike Outfit")
                            .font(.custom("DMSans-Regular", size: 44))
                            .foregroundColor(.black)
                            .multilineTextAlignment(.leading)
                            .padding(.top, 18)
                            .padding(.leading, 40)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Spacer()

                        Button(action: {
                            hasSeenLaunchScreen = true
                            if isSignedIn {
                                path.append(.mainTab)
                            } else {
                                path.append(.auth)
                            }
                        }) {
                            Text("Let's Go")
                                .font(.title2)
                                .fontWeight(.medium)
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.white)
                                .cornerRadius(32)
                                .padding(.horizontal, 24)
                        }
                        .padding(.bottom, 40)
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                }
            }
            .onAppear {
                // Auto-navigate if already signed in
                if isSignedIn {
                    path.append(.mainTab)
                }
            }
            .navigationDestination(for: LaunchDestination.self) { destination in
                switch destination {
                case .mainTab:
                    MainTabView()
                case .auth:
                    AuthGate() // Replace with your actual AuthView
                }
            }
        }
    }
}

#Preview {
    LaunchScreenView()
}


