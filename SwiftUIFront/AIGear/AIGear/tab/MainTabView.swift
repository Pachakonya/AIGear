import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0 // Center tab (ChatBot) is default

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                MapContainerView()
                    .tabItem {
                        Label("Map", systemImage: "map")
                    }
                    .tag(0)

                ChatbotView()
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
