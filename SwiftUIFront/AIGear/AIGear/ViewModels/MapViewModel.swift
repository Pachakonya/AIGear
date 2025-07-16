import Foundation
import Combine
import CoreLocation

final class MapViewModel: ObservableObject {
    @Published var userLocation: CLLocation?
    @Published var isAuthorized: Bool = false
    @Published var userAddress: String = ""
    @Published var trailDifficulty: Int? = nil
    @Published var isLoadingTrail: Bool = false
    @Published var userHeading: CLHeading?
    @Published var isHeadingAvailable: Bool = false
    
    // Route confirmation state
    @Published var selectedLocation: CLLocationCoordinate2D?
    @Published var showRouteConfirmation: Bool = false

    private let locationService = LocationService()
    private var cancellables = Set<AnyCancellable>()
    private let geocoder = CLGeocoder()
    private var geocodingTimer: Timer?
    private var lastGeocodedLocation: CLLocation?
    private let minimumDistanceForNewGeocoding: CLLocationDistance = 100 // meters

    init() {
        bindLocationService()
        locationService.requestPermission()
    }

    private func bindLocationService() {
        // Observe permission changes
        locationService.$authorizationStatus
            .sink { [weak self] status in
                guard let status = status else { return }
                self?.isAuthorized = (status == .authorizedWhenInUse || status == .authorizedAlways)
                if self?.isAuthorized == true {
                    self?.locationService.startUpdatingLocation()
                }
            }
            .store(in: &cancellables)

        // Observe location changes with debouncing
        locationService.$currentLocation
            .sink { [weak self] location in
                self?.userLocation = location
                self?.scheduleReverseGeocode(location)
            }
            .store(in: &cancellables)

        // Observe heading changes
        locationService.$currentHeading
            .sink { [weak self] heading in
                self?.userHeading = heading
            }
            .store(in: &cancellables)

        // Observe heading availability
        locationService.$isHeadingAvailable
            .sink { [weak self] available in
                self?.isHeadingAvailable = available
            }
            .store(in: &cancellables)
    }

    private func scheduleReverseGeocode(_ location: CLLocation?) {
        // Cancel any pending geocoding
        geocodingTimer?.invalidate()
        
        guard let location = location else {
            DispatchQueue.main.async {
                self.userAddress = ""
            }
            return
        }
        
        // Check if we've moved significantly from last geocoded location
        if let lastLocation = lastGeocodedLocation,
           location.distance(from: lastLocation) < minimumDistanceForNewGeocoding {
            // Location hasn't changed significantly, skip geocoding
            return
        }
        
        // Schedule geocoding after a delay to debounce rapid updates
        geocodingTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            self?.performReverseGeocode(location)
        }
    }

    private func performReverseGeocode(_ location: CLLocation) {
        // Cancel any pending geocoding requests
        geocoder.cancelGeocode()
        
        lastGeocodedLocation = location
        
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            guard let self = self else { return }
            
            if let error = error as NSError? {
                // Check for rate limit error
                if error.domain == kCLErrorDomain && error.code == CLError.Code.geocodeFoundNoResult.rawValue {
                    print("Geocoding rate limited or no result found")
                }
                DispatchQueue.main.async {
                    self.userAddress = "Current Location"
                }
                return
            }
            
            if let placemark = placemarks?.first {
                let street = placemark.thoroughfare ?? ""
                let number = placemark.subThoroughfare ?? ""
                let city = placemark.locality ?? ""
                let address = [street, number, city].filter { !$0.isEmpty }.joined(separator: ", ")
                DispatchQueue.main.async {
                    self.userAddress = address.isEmpty ? "Current Location" : address
                }
            } else {
                DispatchQueue.main.async {
                    self.userAddress = "Current Location"
                }
            }
        }
    }

    // Call this when you fetch trail conditions for a selected route
    func updateDifficulty(from trailConditions: [TrailCondition]) {
        let difficulties = trailConditions.compactMap { $0.sacScale }.map { Self.difficultyFromSacScale($0) }
        if let maxDifficulty = difficulties.max() {
            self.trailDifficulty = maxDifficulty
        } else {
            self.trailDifficulty = nil
        }
    }

    static func difficultyFromSacScale(_ sacScale: String) -> Int {
        switch sacScale {
        case "hiking": return 1
        case "mountain_hiking": return 3
        case "demanding_mountain_hiking": return 5
        case "alpine_hiking": return 7
        case "demanding_alpine_hiking": return 9
        case "difficult_alpine_hiking": return 10
        default: return 1
        }
    }

    func centerOnUser() -> CLLocationCoordinate2D? {
        return userLocation?.coordinate
    }
    
    // Route confirmation methods
    func showRouteConfirmationDialog(for coordinate: CLLocationCoordinate2D) {
        selectedLocation = coordinate
        showRouteConfirmation = true
    }
    
    func cancelRouteSelection() {
        selectedLocation = nil
        showRouteConfirmation = false
    }
    
    func confirmRouteBuilding() {
        showRouteConfirmation = false
        // The actual route building will be handled by the map view
    }
}

