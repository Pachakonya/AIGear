import SwiftUI

// Import notification names
//extension Notification.Name {
//    static let navigateToHikeAssistant = Notification.Name("navigateToHikeAssistant")
//}

struct MainTabView: View {
    @State private var selectedTab = 0 // Center tab (ChatBot) is default
    @StateObject private var gearVM = GearViewModel.shared

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                MapContainerView()
                    .tabItem {
                        Label("Map", systemImage: "map")
                    }
                    .tag(0)

                ChatbotView(selectedTab: $selectedTab)
                    .tabItem {
                        // Empty label, we'll overlay a custom button
                        Text("")
                    }
                    .tag(1)

                GearView()
                    .tabItem {
                        Label("Gear", systemImage: "figure.hiking")
                    }
                    .tag(2)
            }
            .accentColor(.black)
            .onReceive(gearVM.$shouldNavigateToGear) { value in
                if value {
                    selectedTab = 2
                    gearVM.shouldNavigateToGear = false
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .navigateToHikeAssistant)) { _ in
                selectedTab = 1 // Navigate to ChatbotView (hike assistant)
            }

            // Overlay the horse icon, ignoring safe area
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: { selectedTab = 1 }) {
                        ZStack {
                            if selectedTab == 1 {
                                Circle()
                                    .stroke(Color.black, lineWidth: 4)
                                    .frame(width: 70, height: 70)
                            }

                            Circle()
                                .fill(Color.black)
                                .frame(width: 58, height: 58)
                                .shadow(radius: 6)
                            
                            Image("horse_icon_white")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 32, height: 32)
                                .foregroundColor(.black)
                        }
                    }
                   
                    Spacer()
                }
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .allowsHitTesting(false)
        }
    }
}
