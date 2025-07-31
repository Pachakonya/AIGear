import SwiftUI
import MapboxMaps
import CoreLocation

struct GearRentalMapView: View {
    let businessName: String
    let address: String
    let coordinate: CLLocationCoordinate2D
    let website: String?
    let phone: String?
    let rating: String?
    
    @Environment(\.dismiss) private var dismiss
    @State private var mapView: MapView?
    
    var body: some View {
        NavigationView {
            ZStack {
                // Mapbox Map
                MapboxMapViewRepresentable(
                    coordinate: coordinate,
                    businessName: businessName,
                    address: address
                )
                .edgesIgnoringSafeArea(.all)
                
                // Business info overlay
                VStack {
                    Spacer()
                    
                    // Business card overlay
                    VStack(alignment: .leading, spacing: 12) {
                        // Business name and rating
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(businessName)
                                    .font(.custom("DMSans-Bold", size: 18))
                                    .foregroundColor(.primary)
                                
                                if let rating = rating {
                                    Text(rating)
                                        .font(.custom("DMSans-Medium", size: 14))
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                        }
                        
                        // Address
                        HStack(spacing: 8) {
                            Image(systemName: "location.fill")
                                .foregroundColor(.secondary)
                                .font(.caption)
                            Text(address)
                                .font(.custom("DMSans-Regular", size: 14))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.leading)
                        }
                        
                        // Action buttons
                        HStack(spacing: 16) {
                            // Website button
                            if let website = website, let url = URL(string: website) {
                                Button(action: {
                                    UIApplication.shared.open(url)
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "globe")
                                        Text("Website")
                                    }
                                    .font(.custom("DMSans-Medium", size: 14))
                                    .foregroundColor(.blue)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(20)
                                }
                            }
                            
                            // Phone button
                            if let phone = phone {
                                Button(action: {
                                    let cleanPhone = phone.replacingOccurrences(of: " ", with: "")
                                        .replacingOccurrences(of: "(", with: "")
                                        .replacingOccurrences(of: ")", with: "")
                                        .replacingOccurrences(of: "-", with: "")
                                    if let url = URL(string: "tel:\(cleanPhone)") {
                                        UIApplication.shared.open(url)
                                    }
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "phone.fill")
                                        Text("Call")
                                    }
                                    .font(.custom("DMSans-Medium", size: 14))
                                    .foregroundColor(.green)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.green.opacity(0.1))
                                    .cornerRadius(20)
                                }
                            }
                            
                            Spacer()
                        }
                    }
                    .padding(20)
                    .background(.ultraThinMaterial)
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: -2)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Location")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .medium))
                            Text("Back")
                                .font(.custom("DMSans-Medium", size: 16))
                        }
                        .foregroundColor(.primary)
                    }
                }
            }
        }
    }
}

// MARK: - Mapbox Map Representable
struct MapboxMapViewRepresentable: UIViewRepresentable {
    let coordinate: CLLocationCoordinate2D
    let businessName: String
    let address: String
    
    func makeUIView(context: Context) -> MapView {
        let mapView = MapView(frame: .zero)
        
        // Configure map
        mapView.mapboxMap.setCamera(to: CameraOptions(
            center: coordinate,
            zoom: 15,
            bearing: 0,
            pitch: 0
        ))
        
        // Add marker for the business location
        addBusinessMarker(to: mapView)
        
        return mapView
    }
    
    func updateUIView(_ mapView: MapView, context: Context) {
        // Update camera position if needed
        mapView.mapboxMap.setCamera(to: CameraOptions(
            center: coordinate,
            zoom: 15
        ))
    }
    
    private func addBusinessMarker(to mapView: MapView) {
        // Create point annotation manager
        let pointAnnotationManager = mapView.annotations.makePointAnnotationManager()
        
        // Create point annotation
        var pointAnnotation = PointAnnotation(coordinate: coordinate)
        pointAnnotation.textField = businessName
        pointAnnotation.textOffset = [0, -2]
        pointAnnotation.textColor = StyleColor(.black)
        pointAnnotation.textHaloColor = StyleColor(.white)
        pointAnnotation.textHaloWidth = 2
        
        // Add custom icon or use default pin
        pointAnnotation.iconImage = "mapbox-marker-icon-default"
        pointAnnotation.iconSize = 1.2
        
        // Add annotation to manager
        pointAnnotationManager.annotations = [pointAnnotation]
    }
}

#Preview {
    GearRentalMapView(
        businessName: "Outdoor Center Almaty",
        address: "Tole Bi Street 25, Almaty",
        coordinate: CLLocationCoordinate2D(latitude: 43.2567, longitude: 76.9286),
        website: "http://www.outdoorcenter.kz/",
        phone: "8 (727) 972 2199",
        rating: "⭐ 4.6/5 (273 reviews)"
    )
} 