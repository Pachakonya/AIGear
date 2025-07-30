import Foundation
import CoreLocation
import Combine

final class LocationService: NSObject, ObservableObject {
    private let locationManager = CLLocationManager()
    
    // Publicly exposed location publisher
    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus?
    @Published var currentHeading: CLHeading?
    @Published var isHeadingAvailable: Bool = false
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        
        // Check if heading is available on this device
        isHeadingAvailable = CLLocationManager.headingAvailable()
    }

    func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func requestLocationOnce() {
        locationManager.requestLocation()
    }

    func startUpdatingLocation() {
        locationManager.startUpdatingLocation()
        
        // Start heading updates if available
        if isHeadingAvailable {
            locationManager.startUpdatingHeading()
        }
    }

    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
        
        // Stop heading updates
        if isHeadingAvailable {
            locationManager.stopUpdatingHeading()
        }
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationService: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus

        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            startUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        currentLocation = latest
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        // Only update if heading is accurate enough
        if newHeading.headingAccuracy > 0 {
            currentHeading = newHeading
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location update failed: \(error)")
    }
}

