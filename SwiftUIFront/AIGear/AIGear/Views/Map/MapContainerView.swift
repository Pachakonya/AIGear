import SwiftUI
import MapKit

struct MapContainerView: View {
    @StateObject private var viewModel = MapViewModel()
    @State private var searchQuery = ""
    @State private var is3D = false
    @State private var showSuggestions = false
    
    var body: some View {
        ZStack(alignment: .top) {
            MapboxOutdoorMapView(viewModel: viewModel, is3D: $is3D)
                .edgesIgnoringSafeArea(.top)
                .allowsHitTesting(!viewModel.isLoadingTrail)
            
            LinearGradient(
                gradient: Gradient(colors: [Color.white.opacity(0.75), Color.clear]),
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 200)
            .ignoresSafeArea(edges: .top)
            .allowsHitTesting(false)
    
            VStack(spacing: 12) {
                HStack {
                    // 📍 Location text
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Your Location")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            
                        Text(viewModel.userAddress.isEmpty ? "Locating..." : viewModel.userAddress)
                            .font(.callout)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Spacer()

                    // 🔵 Hollow circle with number
                    ZStack {
                        Circle()
                            .stroke(Color.orange, lineWidth: 2)
                            .frame(width: 32, height: 32)

                        Text(viewModel.trailDifficulty != nil ? String(viewModel.trailDifficulty!) : "-")
                            .font(.subheadline)
                            .foregroundColor(.black)
                            .fontWeight(.bold)
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(radius: 5)
                .padding(.horizontal)
                
                Spacer()
                
                HStack {
                    Spacer()
                    Button(action: {
                        is3D.toggle()
                    }) {
                        Image(systemName: is3D ? "view.2d" : "view.3d")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.black)
                            .frame(width: 28, height: 24)
                            .padding(14)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                            .shadow(radius: 2)
                    }
                    .padding(.trailing, 16)
                    .padding(.bottom, 4)
                    .disabled(viewModel.isLoadingTrail)
                    .opacity(viewModel.isLoadingTrail ? 0.5 : 1.0)
                }
                
                // 📍 Location Button
                HStack {
                    Spacer()
                    Button(action: {
                        if let coordinate = viewModel.userLocation?.coordinate {
                            NotificationCenter.default.post(name: .centerMapExternally, object: coordinate)
                        }
                    }) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.black)
                            .frame(width: 28, height: 24)
                            .padding(14)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                            .shadow(radius: 2)
                    }
                    .padding(.trailing, 16)
                    .padding(.bottom, 4)
                    .disabled(viewModel.isLoadingTrail)
                    .opacity(viewModel.isLoadingTrail ? 0.5 : 1.0)
                }

                // Bottom Card (Greeting + Search Bar)
                VStack(spacing: 16) {
                    Capsule()
                        .frame(width: 40, height: 5)
                        .foregroundColor(Color.gray.opacity(0.3))
                        .padding(.top, 8)
                    // Search Bar inside card
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        TextField("Where are you hiking?", text: $searchQuery, onEditingChanged: { editing in
                            showSuggestions = editing
                        }, onCommit: {
                            performSearch(query: searchQuery)
                            showSuggestions = false
                        })
                        .foregroundColor(.primary)
                        .autocapitalization(.none)
                        .disabled(viewModel.isLoadingTrail)
                    }
                    .padding()
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(radius: 2)
                    .padding(.horizontal)
                    .opacity(viewModel.isLoadingTrail ? 0.5 : 1.0)

                }
                .padding(.bottom, 24)
                .background(
                    RoundedCorner(radius: 28, corners: [.topLeft, .topRight])
                        .fill(Color(.systemGray6).opacity(0.95))
                )
            }
            
            // Loading overlay
            if viewModel.isLoadingTrail {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        ZStack {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.black.opacity(0.5))
                                .frame(width: 60, height: 60)
                            ProgressView()
                                .scaleEffect(2.0)
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        }
                        Spacer()
                    }
                    Spacer()
                }
                .ignoresSafeArea()
                .allowsHitTesting(true)
            }
        }
    }

    private func performSearch(query: String) {
        guard let userCoordinate = viewModel.userLocation?.coordinate else { return }

        // Set loading state
        viewModel.isLoadingTrail = true

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = MKCoordinateRegion(center: userCoordinate,
                                            latitudinalMeters: 100_000,
                                            longitudinalMeters: 100_000)

        MKLocalSearch(request: request).start { response, error in
            guard let destination = response?.mapItems.first?.placemark.coordinate else { 
                // Reset loading state if search fails
                DispatchQueue.main.async {
                    self.viewModel.isLoadingTrail = false
                }
                return 
            }

            RouteService().fetchRoute(from: userCoordinate, to: destination) { route, conditions in
                guard let route = route else { 
                    // Reset loading state if route fetch fails
                    DispatchQueue.main.async {
                        self.viewModel.isLoadingTrail = false
                    }
                    return 
                }
                
                DispatchQueue.main.async {
                    self.viewModel.updateDifficulty(from: conditions)
                    NotificationCenter.default.post(name: .drawRouteExternally, object: route)
                    
                    // Reset loading state after route is drawn
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        self.viewModel.isLoadingTrail = false
                    }
                }
            }
        }
    }
}

// Custom shape for rounding only specific corners
struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}


