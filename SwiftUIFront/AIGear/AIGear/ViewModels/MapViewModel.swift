import Foundation
import Combine
import CoreLocation

final class MapViewModel: ObservableObject {
    @Published var userLocation: CLLocation?
    @Published var isAuthorized: Bool = false
    @Published var userAddress: String = ""
    @Published var trailDifficulty: Int? = nil

    private let locationService = LocationService()
    private var cancellables = Set<AnyCancellable>()
    private let geocoder = CLGeocoder()

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

        // Observe location changes
        locationService.$currentLocation
            .sink { [weak self] location in
                self?.userLocation = location
                self?.reverseGeocode(location)
            }
            .store(in: &cancellables)
    }

    private func reverseGeocode(_ location: CLLocation?) {
        guard let location = location else {
            DispatchQueue.main.async {
                self.userAddress = ""
            }
            return
        }
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            guard let self = self else { return }
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
}

