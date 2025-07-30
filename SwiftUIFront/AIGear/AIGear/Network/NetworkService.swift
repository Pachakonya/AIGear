import Foundation
import CoreLocation

// MARK: - Profile Models (NEW - added for profile functionality)
struct ProfileUpdateRequest: Codable {
    let age: Int
    let gender: String
    let fitness_level: String
    let hiking_experience_years: Double
}

struct ProfileResponse: Codable {
    let age: Int
    let gender: String
    let fitness_level: String
    let hiking_experience_years: Double
    let profile_completed: Bool
}

struct UserResponse: Codable {
    let id: String
    let email: String
    let username: String?
    let age: Int?
    let gender: String?
    let fitness_level: String?
    let hiking_experience_years: Double?
    let profile_completed: Bool
}

// MARK: - Original Models (RESTORED)
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

struct OrchestratorResponse: Codable {
    let tool_used: String
    let parameters: [String: AnyCodable]
    let response: String
    let raw_response: String?
}

struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode value")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        default:
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: [], debugDescription: "Cannot encode value"))
        }
    }
}

class NetworkService {
    static let shared = NetworkService()
//    private let baseURL = "https://api.aigear.tech"
//    private let baseURL = "http://172.20.10.8:8000" // Hotspot IP
    private let baseURL = "http://192.168.100.84:8000"

    private func addAuthHeader(to request: inout URLRequest) {
        if let token = AuthService.shared.getAuthToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
    }
    
    // MARK: - Profile Methods (NEW)
    func updateProfile(
        age: Int,
        gender: String,
        fitnessLevel: String,
        hikingExperience: Double,
        completion: @escaping (Result<ProfileResponse, Error>) -> Void
    ) {
        guard let url = URL(string: "\(baseURL)/auth/profile") else {
            return completion(.failure(NSError(domain: "Invalid URL", code: 400)))
        }
        
        let body = ProfileUpdateRequest(
            age: age,
            gender: gender,
            fitness_level: fitnessLevel,
            hiking_experience_years: hikingExperience
        )
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        addAuthHeader(to: &request)
        
        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            return completion(.failure(error))
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                return completion(.failure(error))
            }
            
            // Check for HTTP errors
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode >= 400 {
                    let errorMessage = "HTTP Error: \(httpResponse.statusCode)"
                    if let data = data, let errorBody = String(data: data, encoding: .utf8) {
                        print("Error response: \(errorBody)")
                    }
                    return completion(.failure(NSError(domain: errorMessage, code: httpResponse.statusCode)))
                }
            }
            
            guard let data = data else {
                return completion(.failure(NSError(domain: "No Data", code: 404)))
            }
            
            do {
                let decoded = try JSONDecoder().decode(ProfileResponse.self, from: data)
                completion(.success(decoded))
            } catch {
                print("Decoding error: \(error)")
                completion(.failure(error))
            }
        }.resume()
    }
    
    func getCurrentUser(completion: @escaping (Result<UserResponse, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/auth/me") else {
            return completion(.failure(NSError(domain: "Invalid URL", code: 400)))
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addAuthHeader(to: &request)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                return completion(.failure(error))
            }
            
            guard let data = data else {
                return completion(.failure(NSError(domain: "No Data", code: 404)))
            }
            
            do {
                let decoded = try JSONDecoder().decode(UserResponse.self, from: data)
                completion(.success(decoded))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    // MARK: - Original Methods (RESTORED)
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

    func getGearAndHikeSuggestions(prompt: String, completion: @escaping (Result<GearAndHikeResponse, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/aiengine/gear-and-hike-suggest") else {
            return completion(.failure(NSError(domain: "Invalid URL", code: 400)))
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        addAuthHeader(to: &request)
        let body = ["prompt": prompt]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                return completion(.failure(error))
            }
            guard let data = data else {
                return completion(.failure(NSError(domain: "No Data", code: 404)))
            }
            do {
                let decoded = try JSONDecoder().decode(GearAndHikeResponse.self, from: data)
                completion(.success(decoded))
            } catch {
                completion(.failure(error))
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

    func callOrchestrator(prompt: String, userLocation: CLLocation? = nil, completion: @escaping (Result<OrchestratorResponse, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/aiengine/orchestrate") else {
            return completion(.failure(NSError(domain: "Invalid URL", code: 400)))
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30.0 // Add 30 second timeout
        addAuthHeader(to: &request)
        
        var body: [String: Any] = ["prompt": prompt]
        
        // Add location data if available
        if let location = userLocation {
            body["user_latitude"] = location.coordinate.latitude
            body["user_longitude"] = location.coordinate.longitude
            body["location_accuracy"] = location.horizontalAccuracy
        }
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                return completion(.failure(error))
            }
            guard let data = data else {
                return completion(.failure(NSError(domain: "No Data", code: 404)))
            }
            do {
                let decoded = try JSONDecoder().decode(OrchestratorResponse.self, from: data)
                completion(.success(decoded))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
}

