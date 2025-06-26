import Foundation
import CoreLocation

struct ElevationResult: Codable {
    let elevation: Double
}

struct ElevationResponse: Codable {
    let results: [ElevationResult]
}

final class ElevationService {
    static let shared = ElevationService()

    func calculateElevationGain(for coordinates: [CLLocationCoordinate2D], completion: @escaping (Double) -> Void) {
        let elevationAPI = "https://api.open-elevation.com/api/v1/lookup"
        let locations = coordinates.map { ["latitude": $0.latitude, "longitude": $0.longitude] }
        let body = ["locations": locations]

        guard let url = URL(string: elevationAPI),
              let httpBody = try? JSONSerialization.data(withJSONObject: body) else {
            completion(0)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = httpBody

        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data = data,
                  let result = try? JSONDecoder().decode(ElevationResponse.self, from: data) else {
                completion(0)
                return
            }

            let elevations = result.results.map { $0.elevation }
            var gain: Double = 0
            for i in 1..<elevations.count {
                let diff = elevations[i] - elevations[i - 1]
                if diff > 0 { gain += diff }
            }
            completion(gain)
        }.resume()
    }
}

