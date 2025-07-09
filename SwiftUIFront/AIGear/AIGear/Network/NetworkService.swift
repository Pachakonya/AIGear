import Foundation
import CoreLocation

struct GearRequest: Codable {
    let weather: String
    let trail_condition: String
}

struct GearResponse: Codable {
    let recommendations: [String]
}

struct TrailUploadRequest: Codable {
    let coordinates: [[Double]]
    let distance_meters: Double
    let trail_conditions: [String]
    let elevation_gain_meters: Double
}

struct GearAndHikeResponse: Codable {
    let gear: [String]
    let hike: [String]
}

class NetworkService {
    static let shared = NetworkService()
    private let baseURL = "https://api.aigear.tech"
    // private let baseURL = "http://10.68.96.28:8000" // Local Docker

    private func addAuthHeader(to request: inout URLRequest) {
        if let token = AuthService.shared.getAuthToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
    }
    
    func uploadTrailData(
        coordinates: [CLLocationCoordinate2D],
        distance: Double,
        trailConditions: [String],
        elevationGain: Double,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        guard let url = URL(string: "\(baseURL)/gear/upload") else {
            return completion(.failure(NSError(domain: "Invalid URL", code: 400)))
        }

        let body = TrailUploadRequest(
            coordinates: coordinates.map { [$0.latitude, $0.longitude] },
            distance_meters: distance,
            trail_conditions: trailConditions,
            elevation_gain_meters: elevationGain
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        addAuthHeader(to: &request)
        request.httpBody = try? JSONEncoder().encode(body)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                return completion(.failure(error))
            }

            completion(.success("✅ Trail data uploaded"))
        }.resume()
    }

    func getAIGearRecommendation(
        coordinates: [[Double]],
        distance: Double,
        elevationGain: Double,
        trailConditions: [String],
        completion: @escaping (Result<GearResponse, Error>) -> Void
    ) {
        guard let url = URL(string: "\(baseURL)/aiengine/gear-recommend") else {
            return completion(.failure(NSError(domain: "Invalid URL", code: 400)))
        }

        let body = TrailUploadRequest(
            coordinates: coordinates,
            distance_meters: distance,
            trail_conditions: trailConditions,
            elevation_gain_meters: elevationGain
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        addAuthHeader(to: &request)
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
    
    func getGearAndHikeSuggestions(completion: @escaping (Result<GearAndHikeResponse, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/aiengine/gear-and-hike-suggest") else {
            return completion(Result.failure(NSError(domain: "Invalid URL", code: 400)))
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addAuthHeader(to: &request)
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                return completion(Result.failure(error))
            }
            guard let data = data else {
                return completion(Result.failure(NSError(domain: "No Data", code: 404)))
            }
            do {
                let decoded = try JSONDecoder().decode(GearAndHikeResponse.self, from: data)
                completion(Result.success(decoded))
            } catch {
                completion(Result.failure(error))
            }
        }.resume()
    }

    func deleteAccount(completion: @escaping (Result<Void, Error>) -> Void) {
        guard let token = AuthService.shared.getAuthToken() else {
            completion(.failure(NSError(domain: "No token", code: 401)))
            return
        }
        var request = URLRequest(url: URL(string: "\(baseURL)/auth/delete-account")!)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                completion(.failure(NSError(domain: "Delete failed", code: 500)))
                return
            }
            completion(.success(()))
        }.resume()
    }
}

