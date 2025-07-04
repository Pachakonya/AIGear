import SwiftUI

struct GearView: View {
    @State private var showProfile = false

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    Text("Let's hike")
                        .font(.system(size: 32, weight: .bold))
                    Spacer()
                    Button(action: { showProfile = true }) {
                        Image(systemName: "person.crop.circle")
                            .resizable()
                            .frame(width: 40, height: 40)
                            .foregroundColor(.gray)
                            .background(Color.white)
                            .clipShape(Circle())
                            .shadow(radius: 2)
                    }
                    .sheet(isPresented: $showProfile) {
                        ProfileView()
                    }
                }
                .padding(.horizontal)

                // Activity card
                HStack(spacing: 32) {
                    VStack {
                        Text("27")
                            .font(.title)
                            .fontWeight(.bold)
                        Text("hikes")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    VStack {
                        Text("319 km")
                            .font(.title)
                            .fontWeight(.bold)
                        Text("walked this summer")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(.systemGray5))
                .cornerRadius(20)
                .padding(.horizontal)

                // Wardrobe
                VStack(alignment: .leading, spacing: 8) {
                    Text("Wardrobe")
                        .font(.headline)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(0..<3) { i in
                                Image("smart_toples") // Replace with your gear images
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 72, height: 72)
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    .shadow(radius: 2)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                .padding(.horizontal)

                Spacer()
            }
            .background(Color(.systemGray6).ignoresSafeArea())
            .navigationBarHidden(true)
        }
    }
}

// struct ProfileStatsView: View {
//     var body: some View {
//         VStack(spacing: 32) {
//             Text("Your activity")
//                 .font(.title2)
//                 .fontWeight(.bold)
//             HStack(spacing: 32) {
//                 VStack {
//                     Text("27")
//                         .font(.title)
//                         .fontWeight(.bold)
//                     Text("hikes")
//                         .font(.caption)
//                         .foregroundColor(.gray)
//                 }
//                 VStack {
//                     Text("319 km")
//                         .font(.title)
//                         .fontWeight(.bold)
//                     Text("walked this summer")
//                         .font(.caption)
//                         .foregroundColor(.gray)
//                 }
//             }
//             Spacer()
//         }
//         .padding()
//     }
// }

