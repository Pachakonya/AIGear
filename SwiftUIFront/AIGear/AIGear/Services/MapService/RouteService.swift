import Foundation
import MapboxDirections
import CoreLocation

final class RouteService {
    private let directions = Directions.shared

    func fetchRoute(
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D,
        saveTrailData: Bool = true,
        completion: @escaping (Route?, [TrailCondition]) -> Void
    ) {
        let originWaypoint = Waypoint(coordinate: origin, name: "Start")
        let destinationWaypoint = Waypoint(coordinate: destination, name: "End")

        let options = RouteOptions(waypoints: [originWaypoint, destinationWaypoint], profileIdentifier: .walking)
        options.includesSteps = true

        directions.calculate(options) { session, result in
            switch result {
            case .failure(let error):
                print("❌ Route error: \(error)")
                completion(nil, [])
            case .success(let response):
                guard let route = response.routes?.first,
                      let coordinates = route.shape?.coordinates else {
                    completion(nil, [])
                    return
                }

                OverpassService.shared.fetchTrailCondition(around: coordinates) { conditions in

                    if saveTrailData {
                        // 🚀 Upload trail data only for hiking routes, not gear rental routes
                        let distance = route.distance
                        let surfaces = conditions.compactMap { $0.surface }.uniqued()

                        ElevationService.shared.calculateElevationGain(for: coordinates) { elevationGain in
                            NetworkService.shared.uploadTrailData(
                                coordinates: coordinates,
                                distance: distance,
                                trailConditions: surfaces,
                                elevationGain: elevationGain
                            ) { result in
                                switch result {
                                case .success(let message):
                                    print(message)
                                case .failure(let error):
                                    print("❌ Upload failed: \(error)")
                                }
                            }
                        }
                    } else {
                        print("🏪 Skipping trail data upload for gear rental route")
                    }

                    // ✅ Return the route and conditions to the caller
                    completion(route, conditions)
                }
            }
        }
    }
}
