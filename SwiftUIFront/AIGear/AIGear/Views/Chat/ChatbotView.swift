import SwiftUI

struct ChatMessage: Identifiable {
    let id = UUID()
    let text: String
    let isUser: Bool
    let toolUsed: String?
    
    init(text: String, isUser: Bool, toolUsed: String? = nil) {
        self.text = text
        self.isUser = isUser
        self.toolUsed = toolUsed
    }
}

struct ChatbotView: View {
    @State private var chatHistory: [ChatMessage] = [
        ChatMessage(text: "Hi! I'm AI Gear Assistant. Ask me for gear suggestions, check your wardrobe, or just chat about hiking.", isUser: false)
    ]
    @State private var userInput: String = ""
    @State private var isLoading: Bool = false
    @FocusState private var isInputFocused: Bool
    
    // @StateObject private var webSocketService = WebSocketService.shared

    var body: some View {
        ZStack {
            AuthBackgroundView(imageName: "launch_hiker")
                .ignoresSafeArea()
            // Full-screen blur overlay
            Color.clear
                .background(.ultraThinMaterial)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Chat history
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(chatHistory) { message in
                                ChatBubble(
                                    text: message.text,
                                    isUser: message.isUser,
                                    toolUsed: message.toolUsed
                                )
                                .id(message.id)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: chatHistory.count) { _ in
                        withAnimation {
                            proxy.scrollTo(chatHistory.last?.id, anchor: .bottom)
                        }
                    }
                }
                
                // Input bar
                HStack(spacing: 12) {
                    TextField("Type your message...", text: $userInput)
                        .textFieldStyle(PlainTextFieldStyle())
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.9))
                        .cornerRadius(20)
                        .focused($isInputFocused)
                        .disabled(isLoading)
                        .onSubmit {
                            sendMessage()
                        }
                    
                    Button(action: sendMessage) {
                        Image(systemName: "paperplane.fill")
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(Color.black)
                            .clipShape(Circle())
                    }
                    .disabled(userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                    .opacity(userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1.0)
                }
                .padding(.horizontal)
                .padding(.vertical, 26)
                .background(Color.white.opacity(0.95))
            }
        }
        .onTapGesture {
            isInputFocused = false
        }
    }
    
    func sendMessage() {
        let trimmedInput = userInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else { return }
        
        // Prevent sending if already loading
        guard !isLoading else { return }
        
        // Add user message
        chatHistory.append(ChatMessage(text: trimmedInput, isUser: true))
        
        // Clear input and show loading
        userInput = ""
        isLoading = true
        isInputFocused = false
        
        // Call orchestrator
        callOrchestrator(for: trimmedInput)
    }
    
    func callOrchestrator(for prompt: String) {
        NetworkService.shared.callOrchestrator(prompt: prompt) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let response):
                    // Parse and structure the response
                    structureOrchestratorResponse(response)
                case .failure(let error):
                    // Check if it's a rate limit error
                    if let nsError = error as NSError?, 
                       nsError.domain == "GEOErrorDomain" && nsError.code == 3 {
                        chatHistory.append(ChatMessage(
                            text: "⚠️ Too many requests. Please wait a moment before trying again.", 
                            isUser: false,
                            toolUsed: "error"
                        ))
                    } else {
                        chatHistory.append(ChatMessage(
                            text: "Error: \(error.localizedDescription)", 
                            isUser: false,
                            toolUsed: "error"
                        ))
                    }
                }
            }
        }
    }
    
    func structureOrchestratorResponse(_ response: OrchestratorResponse) {
        // Split the response into logical sections
        let responseText = response.response
        
        if response.tool_used == "gear_recommendation_tool" {
            // Parse gear recommendations by category
            let sections = responseText.components(separatedBy: "\n\n")
            for section in sections where !section.isEmpty {
                // Skip the header and context lines
                if section.starts(with: "Based on") || section.starts(with: "_These recommendations") {
                    continue
                }
                chatHistory.append(ChatMessage(
                    text: section,
                    isUser: false,
                    toolUsed: response.tool_used
                ))
            }
            
            // Add context as a separate message
            if let contextLine = sections.first(where: { $0.starts(with: "_These recommendations") }) {
                chatHistory.append(ChatMessage(
                    text: contextLine.trimmingCharacters(in: CharacterSet(charactersIn: "_")),
                    isUser: false,
                    toolUsed: "context"
                ))
            }
        } else if response.tool_used == "trail_analysis_tool" {
            // Split trail analysis into sections
            let sections = responseText.components(separatedBy: "\n\n")
            for section in sections where !section.isEmpty {
                chatHistory.append(ChatMessage(
                    text: section,
                    isUser: false,
                    toolUsed: response.tool_used
                ))
            }
        } else {
            // For other tools, add as single message
            chatHistory.append(ChatMessage(
                text: responseText,
                isUser: false,
                toolUsed: response.tool_used
            ))
        }
        
        // Add follow-up suggestion
        if response.tool_used == "gear_recommendation_tool" {
            chatHistory.append(ChatMessage(
                text: "Would you like me to create a checklist for your hike? Or check if you have any of these items?",
                isUser: false,
                toolUsed: "suggestion"
            ))
        }
    }
}

struct ChatBubble: View {
    let text: String
    let isUser: Bool
    let toolUsed: String?
    
    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 60) }
            
            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                if !isUser && toolUsed != nil && toolUsed != "context" && toolUsed != "suggestion" {
                    Text(toolLabel)
                        .font(.custom("DMSans-Regular", size: 11))
                        .foregroundColor(.gray)
                        .padding(.horizontal, 8)
                }
                
                Text(text)
                    .font(.custom("DMSans-Regular", size: 16))
                    .foregroundColor(isUser ? .white : .black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(backgroundColor)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(borderColor, lineWidth: isUser ? 0 : 1)
                    )
            }
            
            if !isUser { Spacer(minLength: 60) }
        }
    }
    
    var backgroundColor: Color {
        if isUser {
            return Color.black
        } else if toolUsed == "context" {
            return Color.gray.opacity(0.1)
        } else if toolUsed == "suggestion" {
            return Color.blue.opacity(0.1)
        } else {
            return Color.white
        }
    }
    
    var borderColor: Color {
        if toolUsed == "suggestion" {
            return Color.blue.opacity(0.3)
        } else {
            return Color.gray.opacity(0.2)
        }
    }
    
    var toolLabel: String {
        switch toolUsed {
        case "gear_recommendation_tool":
            return "🎒 Gear Recommendation"
        case "wardrobe_inventory_tool":
            return "👕 Wardrobe Check"
        case "trail_analysis_tool":
            return "📊 Trail Analysis"
        case "chat_tool":
            return "💬 General Info"
        default:
            return ""
        }
    }
}

//#Preview{
//    MainTabView()
//}

