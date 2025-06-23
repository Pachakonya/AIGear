import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house")
                }

            MapContainerView()
                .tabItem {
                    Label("Map", systemImage: "map")
                }

            GearView()
                .tabItem {
                    Label("Gear", systemImage: "person")
                }
        }
    }
}

#Preview {
    MainTabView()
}
