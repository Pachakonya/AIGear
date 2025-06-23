import SwiftUI

struct GearView: View {
    @State private var selectedTab = "Backpacks"
    let categories = ["Backpacks", "Footwear", "Clothing", "Outerwear", "Shelter", "Accesories", "Essentials"]

    var body: some View {
        NavigationView {
            VStack(alignment: .leading) {
                HStack {
                    Spacer()
                    
                    Text("Wardrobe")
                        .font(.headline)
                    
                    Spacer()
                }
                .padding(.vertical)
                .navigationBarHidden(true)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 20) {
                        ForEach(categories, id: \.self) { category in
                            VStack(spacing: 4) {
                                Text(category)
                                    .font(.caption)
                                    .fontWeight(selectedTab == category ? .bold : .regular)
                                    .foregroundColor(selectedTab == category ? .white : .black)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(selectedTab == category ? Color.blue : Color.gray.opacity(0.2))
                                    )

                                Capsule()
                                    .fill(selectedTab == category ? Color.blue : Color.clear)
                                    .frame(height: 3)
                            }
                            .onTapGesture {
                                selectedTab = category
                            }
                        }
                    }
                    .padding(.horizontal)
                }

                ScrollView {
                    VStack(spacing: 20) {
                        GearItem(imageName: "backpack", title: "Osprey Atmos AG 65", subtitle: "Waterproof, Winter")
                        GearItem(imageName: "backpack", title: "Gregory Baltoro 65", subtitle: "Lightweight, Summer")
                        GearItem(imageName: "backpack", title: "Deuter Speed Lite 20", subtitle: "Daypack, 20L")
                    }
                    .padding()
                }

                Spacer()

                HStack {
                    Spacer()
                    NavigationLink(destination: Text("Add Gear View")) {
                        Image(systemName: "plus")
                            .foregroundColor(.white)
                            .frame(width: 50, height: 50)
                            .background(Color.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(radius: 3)
                    }
                    .padding()
                }
            }
        }
    }
}

struct GearItem: View {
    let imageName: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Image(systemName: imageName)
                .resizable()
                .scaledToFit()
                .frame(width: 50, height: 50)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .fontWeight(.medium)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.blue)
            }
            Spacer()
        }
    }
}

#Preview {
    GearView()
}

