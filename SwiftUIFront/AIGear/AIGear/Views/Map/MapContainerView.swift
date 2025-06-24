import SwiftUI
import MapKit

struct MapContainerView: View {
    @StateObject private var viewModel = MapViewModel()
    @State private var searchQuery = ""
    @State private var is3D = false

    var body: some View {
        ZStack(alignment: .top) {
            MapboxOutdoorMapView(viewModel: viewModel, is3D: $is3D)
                .edgesIgnoringSafeArea(.all)
            
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
                    // 👤 Profile image
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .frame(width: 36, height: 36)
                        .foregroundColor(.black)
                        .background(Color.white)
                        .clipShape(Circle())

                    Spacer()

                    // 📍 Location text
                    VStack(spacing: 2) {
                        Text("Your Location")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text("Uly Dala, 53a")
                            .font(.callout)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }

                    Spacer()

                    // 🔵 Hollow circle with number
                    ZStack {
                        Circle()
                            .stroke(Color.orange, lineWidth: 2)
                            .frame(width: 32, height: 32)

                        Text("4")
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
                            .padding(14)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                            .shadow(radius: 4)
                    }
                    .padding(.trailing, 16)
                    .padding(.bottom, 4)
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
                            .padding(14)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                            .shadow(radius: 4)
                    }
                    .padding(.trailing, 16)
                    .padding(.bottom, 4)
                }
                // 🔍 Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Search for the safe route", text: $searchQuery, onCommit: {
                        performSearch(query: searchQuery)
                    })
                    .foregroundColor(.primary)
                    .autocapitalization(.none)
                }
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(radius: 5)
                .padding(.horizontal)
            }
        }
    }

    private func performSearch(query: String) {
        guard let userCoordinate = viewModel.userLocation?.coordinate else { return }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = MKCoordinateRegion(center: userCoordinate,
                                            latitudinalMeters: 100_000,
                                            longitudinalMeters: 100_000)

        MKLocalSearch(request: request).start { response, error in
            guard let destination = response?.mapItems.first?.placemark.coordinate else { return }

            RouteService().fetchRoute(from: userCoordinate, to: destination) { route, conditions in
                guard let route = route else { return }

                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .drawRouteExternally, object: route)
                }
            }
        }
    }
}

#Preview {
    MapContainerView()
}

