import Foundation
import MapboxDirections
import CoreLocation

final class RouteService {
    private let directions = Directions.shared

    func fetchRoute(from origin: CLLocationCoordinate2D,
                    to destination: CLLocationCoordinate2D,
                    completion: @escaping (Route?) -> Void) {

        // Define waypoints (without using targetCoordinate to avoid Navigation SDK dependency)
        let originWaypoint = Waypoint(coordinate: origin, name: "Start")
        let destinationWaypoint = Waypoint(coordinate: destination, name: "End")

        // Use basic RouteOptions instead of NavigationRouteOptions
        let options = RouteOptions(waypoints: [originWaypoint, destinationWaypoint], profileIdentifier: .walking)
        options.includesSteps = true

        directions.calculate(options) { session, result in
            switch result {
            case .failure(let error):
                print("❌ Route error: \(error)")
                completion(nil)
            case .success(let response):
                guard let route = response.routes?.first else {
                    completion(nil)
                    return
                }
                completion(route)
            }
        }
    }
}
