import SwiftUI

struct ChatMessage: Identifiable {
    let id = UUID()
    let text: String
    let isUser: Bool
}

struct ChatbotView: View {
    @State private var chatHistory: [ChatMessage] = [
        ChatMessage(text: "Hi! Ask me for gear or hike suggestions for your latest route.", isUser: false)
    ]
    @State private var userInput: String = ""
    @State private var isLoading: Bool = false
    @FocusState private var isInputFocused: Bool
    
    // WebSocket implementation (commented out for now)
    // @StateObject private var webSocketService = WebSocketService.shared

    var body: some View {
        VStack {
            // WebSocket connection status indicator (commented out for now)
            /*
            HStack {
                Circle()
                    .fill(webSocketService.isConnected ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                Text(webSocketService.isConnected ? "Connected" : "Disconnected")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal)
            */
            
            ScrollViewReader { scrollProxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(chatHistory) { message in
                            HStack {
                                if message.isUser { Spacer() }
                                Text(message.text)
                                    .padding(12)
                                    .background(message.isUser ? Color.blue.opacity(0.15) : Color.gray.opacity(0.12))
                                    .foregroundColor(.primary)
                                    .cornerRadius(16)
                                if !message.isUser { Spacer() }
                            }
                        }
                        if isLoading {
                            HStack {
                                ProgressView().progressViewStyle(CircularProgressViewStyle())
                                Text("Thinking...")
                                    .foregroundColor(.gray)
                                Spacer()
                            }
                        }
                    }
                    .padding(.vertical)
                }
                .onChange(of: chatHistory.count, initial: false) { _, _ in
                    withAnimation { scrollProxy.scrollTo(chatHistory.last?.id, anchor: .bottom) }
                }
            }
            Divider()
            HStack {
                TextField("Type your message...", text: $userInput)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .focused($isInputFocused)
                Button(action: sendMessage) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(userInput.isEmpty ? .gray : .blue)
                }
                .disabled(userInput.isEmpty)
            }
            .padding()
        }
                .navigationTitle("AI Trail Chatbot")
        .contentShape(Rectangle())
        .onTapGesture {
            UIApplication.shared.endEditing()
        }
        
        // WebSocket lifecycle management (commented out for now)
        /*
        .onAppear {
            setupWebSocket()
        }
        .onDisappear {
            webSocketService.disconnect()
        }
        .onReceive(NotificationCenter.default.publisher(for: .websocketMessageReceived)) { notification in
            if let message = notification.userInfo?["message"] as? String {
                handleWebSocketResponse(message)
            }
        }
        .onChange(of: webSocketService.lastError) { _, error in
            if let error = error {
                chatHistory.append(ChatMessage(text: "Connection error: \(error)", isUser: false))
            }
        }
        */
    }

    func sendMessage() {
        guard !userInput.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let userMsg = ChatMessage(text: userInput, isUser: true)
        chatHistory.append(userMsg)
        isLoading = true
        let prompt = userInput.lowercased()
        userInput = ""
        isInputFocused = false
        // Simulate intent: if user asks for gear/hike, fetch from backend
        if prompt.contains("gear") || prompt.contains("hike") || prompt.contains("suggest") {
            fetchGearAndHikeSuggestions()
        } else {
            // Fallback: echo or simple bot reply
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                chatHistory.append(ChatMessage(text: "Ask me for gear or hike suggestions for your latest route!", isUser: false))
                isLoading = false
            }
        }
    }

    func fetchGearAndHikeSuggestions() {
        NetworkService.shared.getGearAndHikeSuggestions { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let decoded):
                    let gearText = "🧢 Gear Suggestions:\n" + decoded.gear.map { "• \($0)" }.joined(separator: "\n")
                    let hikeText = "🥾 Hike Tips:\n" + decoded.hike.map { "• \($0)" }.joined(separator: "\n")
                    chatHistory.append(ChatMessage(text: gearText + "\n\n" + hikeText, isUser: false))
                case .failure(let error):
                    chatHistory.append(ChatMessage(text: "Error: \(error.localizedDescription)", isUser: false))
                }
            }
        }
    }
    
    // WebSocket implementation (commented out for now)
    /*
    private func setupWebSocket() {
        webSocketService.connect()
    }
    
    private func handleWebSocketResponse(_ message: String) {
        DispatchQueue.main.async {
            self.isLoading = false
            self.chatHistory.append(ChatMessage(text: message, isUser: false))
        }
    }
    */
}

