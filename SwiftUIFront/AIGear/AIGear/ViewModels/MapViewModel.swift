import Foundation
import Combine
import CoreLocation

final class MapViewModel: ObservableObject {
    @Published var userLocation: CLLocation?
    @Published var isAuthorized: Bool = false

    private let locationService = LocationService()
    private var cancellables = Set<AnyCancellable>()

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
            .assign(to: \.userLocation, on: self)
            .store(in: &cancellables)
    }

    func centerOnUser() -> CLLocationCoordinate2D? {
        return userLocation?.coordinate
    }
}

