import Foundation

struct AuthResponse: Codable {
    let access_token: String
    let token_type: String
    let user: UserData
}

struct UserData: Codable {
    let id: String
    let email: String
    let username: String?
}

struct LoginRequest: Codable {
    let email: String
    let password: String
}

struct SignUpRequest: Codable {
    let email: String
    let password: String
    let username: String?
}

struct VerificationRequest: Codable {
    let email: String
    let code: String
}

class AuthService: ObservableObject {
    static let shared = AuthService()
    
    @Published var isAuthenticated = false
    @Published var currentUser: UserData?
    @Published var isLoading = false
    
    private let baseURL = "https://api.aigear.tech"
    private let tokenKey = "auth_token"
    private let userKey = "user_data"
    
    init() {
        loadStoredAuth()
    }
    
    private func loadStoredAuth() {
        if let token = UserDefaults.standard.string(forKey: tokenKey),
           let userData = UserDefaults.standard.data(forKey: userKey),
           let user = try? JSONDecoder().decode(UserData.self, from: userData) {
            self.currentUser = user
            self.isAuthenticated = true
        }
    }
    
    private func storeAuth(token: String, user: UserData) {
        UserDefaults.standard.set(token, forKey: tokenKey)
        if let userData = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(userData, forKey: userKey)
        }
        self.currentUser = user
        self.isAuthenticated = true
    }
    
    func clearAuth() {
        UserDefaults.standard.removeObject(forKey: tokenKey)
        UserDefaults.standard.removeObject(forKey: userKey)
        self.currentUser = nil
        self.isAuthenticated = false
    }
    
    func getAuthToken() -> String? {
        return UserDefaults.standard.string(forKey: tokenKey)
    }
    
    func signIn(email: String, password: String) async throws -> Bool {
        await setLoading(true)
        defer { Task { @MainActor in self.setLoading(false) } }
        
        guard let url = URL(string: "\(baseURL)/auth/login") else {
            throw AuthError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let loginRequest = LoginRequest(email: email, password: password)
        request.httpBody = try JSONEncoder().encode(loginRequest)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.networkError
        }
        
        if httpResponse.statusCode == 200 {
            let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
            storeAuth(token: authResponse.access_token, user: authResponse.user)
            return true
        } else {
            throw AuthError.invalidCredentials
        }
    }
    
    func signUp(email: String, password: String, username: String? = nil) async throws -> Bool {
        await setLoading(true)
        defer { Task { @MainActor in self.setLoading(false) } }
        
        guard let url = URL(string: "\(baseURL)/auth/register") else {
            throw AuthError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let signUpRequest = SignUpRequest(email: email, password: password, username: username)
        request.httpBody = try JSONEncoder().encode(signUpRequest)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.networkError
        }
        
        if httpResponse.statusCode == 201 {
            // Registration successful, but user needs to verify email
            return true
        } else {
            throw AuthError.registrationFailed
        }
    }
    
    func verifyEmail(email: String, code: String) async throws -> Bool {
        await setLoading(true)
        defer { Task { @MainActor in self.setLoading(false) } }
        
        guard let url = URL(string: "\(baseURL)/auth/verify") else {
            throw AuthError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let verifyRequest = VerificationRequest(email: email, code: code)
        request.httpBody = try JSONEncoder().encode(verifyRequest)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.networkError
        }
        
        if httpResponse.statusCode == 200 {
            let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
            storeAuth(token: authResponse.access_token, user: authResponse.user)
            return true
        } else {
            throw AuthError.verificationFailed
        }
    }
    
    func signOut() {
        clearAuth()
    }
    
    func signInWithGoogle(idToken: String) async {
        guard let url = URL(string: "\(baseURL)/auth/google") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = ["token": idToken]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                print("Google sign-in failed")
                return
            }
            let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
            await MainActor.run {
                self.storeAuth(token: authResponse.access_token, user: authResponse.user)
            }
        } catch {
            print("Google sign-in error: \(error)")
        }
    }
    
    @MainActor
    private func setLoading(_ value: Bool) {
        self.isLoading = value
    }
}

enum AuthError: Error, LocalizedError {
    case invalidURL
    case networkError
    case invalidCredentials
    case registrationFailed
    case verificationFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .networkError:
            return "Network error occurred"
        case .invalidCredentials:
            return "Invalid email or password"
        case .registrationFailed:
            return "Registration failed"
        case .verificationFailed:
            return "Email verification failed"
        }
    }
} 