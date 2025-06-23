import Foundation
import CoreLocation

final class OverpassService {
    static let shared = OverpassService()

    func fetchTrailCondition(around routeCoords: [CLLocationCoordinate2D], completion: @escaping ([TrailCondition]) -> Void) {
        guard let bbox = boundingBox(for: routeCoords) else {
            completion([])
            return
        }

        let query = """
        [out:json];
        (
          way["highway"~"path|footway|track"](\(bbox.south),\(bbox.west),\(bbox.north),\(bbox.east));
        );
        out tags;
        """
        let urlString = "https://overpass-api.de/api/interpreter?data=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)"

        URLSession.shared.dataTask(with: URL(string: urlString)!) { data, _, error in
            guard let data = data, error == nil else {
                print("❌ OSM error:", error?.localizedDescription ?? "Unknown")
                completion([])
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let elements = json["elements"] as? [[String: Any]],
                   let tags = elements.first?["tags"] as? [String: String] {

                    let condition = TrailCondition(
                        surface: tags["surface"],
                        sacScale: tags["sac_scale"],
                        trailVisibility: tags["trail_visibility"]
                    )
                    completion([condition])
                } else {
                    completion([])
                }
            } catch {
                print("❌ Parsing error:", error)
                completion([])
            }
        }.resume()
    }

    private func boundingBox(for coords: [CLLocationCoordinate2D]) -> (south: Double, west: Double, north: Double, east: Double)? {
        guard !coords.isEmpty else { return nil }

        var minLat = coords[0].latitude, maxLat = coords[0].latitude
        var minLon = coords[0].longitude, maxLon = coords[0].longitude

        for coord in coords {
            minLat = min(minLat, coord.latitude)
            maxLat = max(maxLat, coord.latitude)
            minLon = min(minLon, coord.longitude)
            maxLon = max(maxLon, coord.longitude)
        }

        return (south: minLat, west: minLon, north: maxLat, east: maxLon)
    }
}
