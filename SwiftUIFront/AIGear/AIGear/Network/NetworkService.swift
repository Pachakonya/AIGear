import Foundation

struct GearRequest: Codable {
    let weather: String
    let trail_condition: String
}

struct GearResponse: Codable {
    let recommendations: [String]
}

class NetworkService {
    static let shared = NetworkService()
    private let baseURL = "http://172.20.10.8:8000" // ← REPLACE with your IP

    func getGearRecommendation(weather: String, trailCondition: String, completion: @escaping (Result<GearResponse, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/gear/recommend") else {
            return completion(.failure(NSError(domain: "Invalid URL", code: 400)))
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = GearRequest(weather: weather, trail_condition: trailCondition)
        request.httpBody = try? JSONEncoder().encode(body)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                return completion(.failure(error))
            }

            guard let data = data else {
                return completion(.failure(NSError(domain: "No Data", code: 404)))
            }

            do {
                let decoded = try JSONDecoder().decode(GearResponse.self, from: data)
                completion(.success(decoded))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
}

