import SwiftUI
import MapKit

struct MapContainerView: View {
    @StateObject private var viewModel = MapViewModel()
    @State private var searchQuery = ""

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            MapboxOutdoorMapView(viewModel: viewModel)
                .edgesIgnoringSafeArea(.top)

            VStack(alignment: .trailing, spacing: 4) {
                // 📍 Center Button
                Button(action: {
                    if let coordinate = viewModel.userLocation?.coordinate {
                        NotificationCenter.default.post(name: .centerMapExternally, object: coordinate)
                    }
                }) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.black)
                        .padding()
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .shadow(radius: 4)
                }
                .padding(.trailing, 16)

                // 🔍 Search Bar
                HStack {
                    TextField("Search hike route", text: $searchQuery, onCommit: {
                        performSearch(query: searchQuery)
                    })
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(8)
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
                    .shadow(radius: 3)
                }
                .padding([.horizontal, .bottom], 16)
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

            RouteService().fetchRoute(from: userCoordinate, to: destination) { route in
                guard let route = route else { return }

                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .drawRouteExternally, object: route)
                }
            }
        }
    }
}

