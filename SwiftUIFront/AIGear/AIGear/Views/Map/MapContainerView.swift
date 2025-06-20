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
                .padding(8)
//                .padding(.bottom, 16)
//                .padding(.trailing, 20)
                
                // 🔍 Search Bar
                HStack {
                    TextField("Search hike route", text: $searchQuery, onCommit: {
                        performSearch(query: searchQuery)
                    })
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(8)
                    .background(Color(.systemBackground))
                    .shadow(radius: 3)

//                    Button(action: {
//                        performSearch(query: searchQuery)
//                    }) {
//                        Image(systemName: "magnifyingglass")
//                            .foregroundColor(.black)
//                    }
                }
            }
        }
    }

    // 🍏 Simple MapKit Search
    private func performSearch(query: String) {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query

        let search = MKLocalSearch(request: request)
        search.start { response, error in
            guard let coordinate = response?.mapItems.first?.placemark.coordinate else { return }
            NotificationCenter.default.post(name: .centerMapExternally, object: coordinate)
        }
    }
}

