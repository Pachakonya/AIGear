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
                .onTapGesture {
                    // Dismiss route confirmation when tapping on map
                    if viewModel.showRouteConfirmation {
                        viewModel.cancelRouteSelection()
                        NotificationCenter.default.post(name: .cancelRouteSelection, object: nil)
                    }
                }
            
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
                            // Dismiss route confirmation when user starts searching
                            if editing && viewModel.showRouteConfirmation {
                                viewModel.cancelRouteSelection()
                                NotificationCenter.default.post(name: .cancelRouteSelection, object: nil)
                            }
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
            
            // Route confirmation overlay
            if viewModel.showRouteConfirmation {
                VStack {
                    Spacer()
                    
                    HStack {
                        Spacer()
                        
                        VStack(spacing: 16) {
                            // Action buttons only
                            VStack(spacing: 8) {
                                HStack(spacing: 16) {
                                    Button(action: {
                                        viewModel.cancelRouteSelection()
                                        NotificationCenter.default.post(name: .cancelRouteSelection, object: nil)
                                    }) {
                                        Text("Cancel")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(Color.gray.opacity(0.1))
                                            .cornerRadius(8)
                                    }
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        viewModel.confirmRouteBuilding()
                                        NotificationCenter.default.post(name: .confirmRouteBuilding, object: nil)
                                    }) {
                                        HStack {
                                            Image(systemName: "location.fill")
                                            Text("Build Route")
                                        }
                                        .font(.subheadline)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(Color.blue)
                                        .cornerRadius(8)
                                    }
                                }
                            }
                            .padding()
                            .background(.ultraThinMaterial)
                            .cornerRadius(16)
                            .shadow(radius: 10)
                            // .padding(.horizontal)
                        }
                        
                        Spacer()
                    }
                    .padding(.bottom, 120) // Lower position - increased from 140
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: viewModel.showRouteConfirmation)
            }
        }
    }

    private func performSearch(query: String) {
        guard let userCoordinate = viewModel.userLocation?.coordinate else { return }
        
        // Dismiss any existing route confirmation
        if viewModel.showRouteConfirmation {
            viewModel.cancelRouteSelection()
            NotificationCenter.default.post(name: .cancelRouteSelection, object: nil)
        }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = MKCoordinateRegion(center: userCoordinate,
                                            latitudinalMeters: 100_000,
                                            longitudinalMeters: 100_000)

        MKLocalSearch(request: request).start { response, error in
            guard let destination = response?.mapItems.first?.placemark.coordinate else { 
                print("⚠️ No search results found for: \(query)")
                return 
            }

            DispatchQueue.main.async {
                // Show pin at search result location (same as tap behavior)
                NotificationCenter.default.post(name: .showPinAtLocation, object: destination)
                
                // Show route confirmation dialog (same as tap behavior)
                self.viewModel.showRouteConfirmationDialog(for: destination)
                
                // Center map on the found location
                NotificationCenter.default.post(name: .centerMapExternally, object: destination)
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


