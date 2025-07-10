import SwiftUI

struct GearView: View {
    @State private var showProfile = false
    @ObservedObject private var gearVM = GearViewModel.shared

    var body: some View {
        NavigationView {
            VStack() {
                // Header
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

                // Checklist banner directly under header
                if !gearVM.checklistItems.isEmpty {
                    ChecklistBanner()
                        .padding(.horizontal)
                }

                // Activity card
                // HStack(spacing: 32) {
                //     VStack {
                //         Text("27")
                //             .font(.title)
                //             .fontWeight(.bold)
                //         Text("hikes")
                //             .font(.caption)
                //             .foregroundColor(.gray)
                //     }
                //     VStack {
                //         Text("319 km")
                //             .font(.title)
                //             .fontWeight(.bold)
                //         Text("walked this summer")
                //             .font(.caption)
                //             .foregroundColor(.gray)
                //     }
                // }
                // .padding()
                // .frame(maxWidth: .infinity)
                // .background(Color(.systemGray5))
                // .cornerRadius(20)
                // .padding(.horizontal)

                // // Wardrobe
                // VStack(alignment: .leading, spacing: 8) {
                //     Text("Wardrobe")
                //         .font(.headline)
                //     ScrollView(.horizontal, showsIndicators: false) {
                //         HStack(spacing: 16) {
                //             ForEach(0..<3) { i in
                //                 Image("smart_toples") // Replace with your gear images
                //                     .resizable()
                //                     .scaledToFill()
                //                     .frame(width: 72, height: 72)
                //                     .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                //                     .shadow(radius: 2)
                //             }
                //         }
                //         .padding(.vertical, 8)
                //     }
                // }
                // .padding(.horizontal)

                Spacer()
            }
            .background(Color(.systemGray6).ignoresSafeArea())
            .navigationBarHidden(true)
            .sheet(isPresented: $gearVM.showChecklist) {
                ChecklistSheet()
            }
        }
    }
}


struct ChecklistBanner: View {
    @ObservedObject private var gearVM = GearViewModel.shared
    var body: some View {
        HStack {
            Image(systemName: "checklist")
                .font(.system(size: 24))
                .foregroundColor(.black)
            Text("Checklist ready for your hike")
                .font(.custom("DMSans-Regular", size: 16))
            Spacer()
            Button(action: { gearVM.showChecklist = true }) {
                Text("Open")
                    .font(.custom("DMSans-SemiBold", size: 14))
                    .foregroundColor(.black)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.white)
                    .cornerRadius(14)
                    .shadow(color: .black.opacity(0.12), radius: 4, x: 0, y: 2)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

struct ChecklistSheet: View {
    @ObservedObject private var gearVM = GearViewModel.shared
    var body: some View {
        NavigationView {
            List {
                let categories = Array(Set(gearVM.checklistItems.map { $0.category })).sorted()
                ForEach(categories, id: \ .self) { cat in
                    Section(header: Text(cat)) {
                        ForEach(gearVM.checklistItems.filter { $0.category == cat }) { item in
                            Button(action: {
                                gearVM.toggleItem(id: item.id)
                            }) {
                                HStack {
                                    Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(item.isChecked ? .green : .gray)
                                    Text(item.name)
                                        .foregroundColor(.primary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Hike Checklist")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { gearVM.showChecklist = false }
                }
            }
        }
    }
}

