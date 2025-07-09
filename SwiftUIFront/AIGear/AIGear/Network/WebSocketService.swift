// WebSocket implementation (commented out for now - using HTTP instead)
/*
import Foundation
import Network

enum WebSocketMessageType: String, Codable {
    case chat = "chat"
    case response = "response"
    case error = "error"
}

struct WebSocketMessage: Codable {
    let type: WebSocketMessageType
    let message: String
    let timestamp: Double?
}

class WebSocketService: ObservableObject {
    static let shared = WebSocketService()
    
    private var webSocket: URLSessionWebSocketTask?
    private let baseURL = "wss://api.aigear.tech/ws/chat"
    
    @Published var isConnected = false
    @Published var lastError: String?
    
    private init() {}
    
    func connect() {
        guard let url = URL(string: baseURL) else {
            lastError = "Invalid WebSocket URL"
            return
        }
        
        var request = URLRequest(url: url)
        
        // Add authentication header if available
        if let token = AuthService.shared.getAuthToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        print("Connecting to WebSocket: \(baseURL)")
        print("Request headers: \(request.allHTTPHeaderFields ?? [:])")
        
        let session = URLSession(configuration: .default)
        webSocket = session.webSocketTask(with: request)
        
        // Set up connection state monitoring
        webSocket?.resume()
        
        // Start receiving messages immediately
        receiveMessage()
        
        // Check connection status after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if self.webSocket?.state == .running {
                self.isConnected = true
                print("WebSocket connection established successfully")
            } else {
                self.isConnected = false
                self.lastError = "Failed to establish WebSocket connection"
                print("WebSocket connection failed")
            }
        }
    }
    
    func disconnect() {
        webSocket?.cancel(with: .normalClosure, reason: nil)
        webSocket = nil
        isConnected = false
        print("WebSocket disconnected")
    }
    
    func testConnection() {
        print("Testing WebSocket connection...")
        print("URL: \(baseURL)")
        print("Connection status: \(isConnected)")
        print("Last error: \(lastError ?? "None")")
        
        // Send a test ping
        webSocket?.sendPing { error in
            if let error = error {
                print("WebSocket ping failed: \(error)")
            } else {
                print("WebSocket ping successful")
            }
        }
    }
    
    func sendMessage(_ message: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let webSocket = webSocket else {
            completion(.failure(WebSocketError.notConnected))
            return
        }
        
        let wsMessage = WebSocketMessage(
            type: .chat,
            message: message,
            timestamp: Date().timeIntervalSince1970
        )
        
        do {
            let data = try JSONEncoder().encode(wsMessage)
            let message = URLSessionWebSocketTask.Message.data(data)
            
            print("Sending WebSocket message: \(wsMessage.message)")
            webSocket.send(message) { error in
                if let error = error {
                    print("WebSocket send error: \(error)")
                    completion(.failure(error))
                } else {
                    print("WebSocket message sent successfully")
                    completion(.success(()))
                }
            }
        } catch {
            print("WebSocket encoding error: \(error)")
            completion(.failure(error))
        }
    }
    
    private func receiveMessage() {
        guard let webSocket = webSocket else { return }
        
        webSocket.receive { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let message):
                    self?.handleMessage(message)
                    // Continue receiving messages
                    self?.receiveMessage()
                case .failure(let error):
                    self?.lastError = error.localizedDescription
                    self?.isConnected = false
                }
            }
        }
    }
    
    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .data(let data):
            do {
                let wsMessage = try JSONDecoder().decode(WebSocketMessage.self, from: data)
                handleWebSocketMessage(wsMessage)
            } catch {
                lastError = "Failed to decode message: \(error.localizedDescription)"
            }
        case .string(let string):
            // Handle string messages if needed
            print("Received string message: \(string)")
        @unknown default:
            break
        }
    }
    
    private func handleWebSocketMessage(_ message: WebSocketMessage) {
        print("Received WebSocket message: \(message.message)")
        switch message.type {
        case .response:
            // Handle response message
            NotificationCenter.default.post(
                name: .websocketMessageReceived,
                object: nil,
                userInfo: ["message": message.message]
            )
        case .error:
            lastError = message.message
        case .chat:
            // This shouldn't happen from server
            break
        }
    }
}

enum WebSocketError: Error {
    case notConnected
    case invalidMessage
}

extension Notification.Name {
    static let websocketMessageReceived = Notification.Name("websocketMessageReceived")
}
*/ 