import SwiftUI

struct ChatMessage: Identifiable {
    let id = UUID()
    let text: String
    let isUser: Bool
    let toolUsed: String?
    let payload: String?
    
    init(text: String, isUser: Bool, toolUsed: String? = nil, payload: String? = nil) {
        self.text = text
        self.isUser = isUser
        self.toolUsed = toolUsed
        self.payload = payload
    }
}

struct ChatbotView: View {
    @State private var chatHistory: [ChatMessage] = [
        ChatMessage(text: "Hi! I'm AI Gear Assistant. Ask me for gear suggestions, check your wardrobe, or just chat about hiking.", isUser: false)
    ]
    @State private var userInput: String = ""
    @State private var isLoading: Bool = false
    @FocusState private var isInputFocused: Bool
    
    // Trip-spec states
    @State private var showTripSpecSheet: Bool = false
    @State private var tripDays: Int = 1
    @State private var tripOvernight: Bool = false
    @State private var tripSeason: String = "summer"
    @State private var tripCompanions: Int = 1
    
    // Track if user customized trip specs & if reminder already shown
    @State private var tripCustomized: Bool = false
    @State private var tripReminderShown: Bool = false
    
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
                                    toolUsed: message.toolUsed,
                                    payload: message.payload
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
                    
                    // Trip-spec settings button (replaces send icon)
                    Button(action: {
                        showTripSpecSheet = true
                    }) {
                        Image(systemName: "slider.horizontal.3")
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(Color.black)
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 26)
                .background(Color.white.opacity(0.95))
            }
        }
        // Sheet for collecting trip parameters
        .sheet(isPresented: $showTripSpecSheet) {
            TripSpecView(
                days: $tripDays,
                overnight: $tripOvernight,
                season: $tripSeason,
                companions: $tripCompanions
            ) {
                // On Save – add a context bubble summarizing trip specs
                let overnightText = tripOvernight ? "overnight" : "day hike"
                let summary = "_Trip details: \(tripDays) day(s), \(overnightText), season: \(tripSeason.capitalized), companions: \(tripCompanions)_"
                chatHistory.append(ChatMessage(text: summary, isUser: false, toolUsed: "context"))
                
                tripCustomized = true // mark as customized
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
        
        // If user hasn't customized trip specs yet, show one-time reminder
        if !tripCustomized && !tripReminderShown {
            chatHistory.append(ChatMessage(
                text: "ℹ️ Tip: For more tailored gear suggestions, tap the slider icon (top-right) to fill in trip details like days, season, and if you'll be overnighting.",
                isUser: false,
                toolUsed: "suggestion"
            ))
            tripReminderShown = true
        }
        
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
        // Create a single, well-formatted message instead of multiple bubbles
        let responseText = response.response
        
        if response.tool_used == "gear_recommendation_tool" {
            // Add the entire gear recommendation as one message
            chatHistory.append(ChatMessage(
                text: responseText,
                isUser: false,
                toolUsed: response.tool_used,
                payload: responseText
            ))
            
            // Add follow-up suggestion
            chatHistory.append(ChatMessage(
                text: "Would you like me to create a checklist for your hike? Or check if you have any of these items?",
                isUser: false,
                toolUsed: "suggestion"
            ))
            
            // After adding follow-up suggestion also add checklist action message
            chatHistory.append(ChatMessage(
                text: "Create Checklist",
                isUser: false,
                toolUsed: "checklist_action",
                payload: responseText
            ))
        } else if response.tool_used == "trail_analysis_tool" {
            // Add trail analysis as one message
            chatHistory.append(ChatMessage(
                text: responseText,
                isUser: false,
                toolUsed: response.tool_used
            ))
        } else {
            // For other tools, add as single message
            chatHistory.append(ChatMessage(
                text: responseText,
                isUser: false,
                toolUsed: response.tool_used
            ))
        }
    }
}

struct ChatBubble: View {
    let text: String
    let isUser: Bool
    let toolUsed: String?
    let payload: String?
    
    @ObservedObject private var gearVM = GearViewModel.shared
    
    var body: some View {
        // Special rendering for checklist action
        if toolUsed == "checklist_action" {
            HStack {
                Spacer(minLength: 60)
                Button(action: {
                    if let rec = payload {
                        gearVM.createChecklistFromRecommendations(rec)
                        gearVM.shouldNavigateToGear = true
                    }
                }) {
                    Text(text)
                        .font(.custom("DMSans-SemiBold", size: 16))
                        .foregroundColor(.black)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.white)
                        .cornerRadius(24)
                        .shadow(color: .black.opacity(0.12), radius: 4, x: 0, y: 2)
                }
                Spacer(minLength: 60)
            }
        } else {
            standardBubble
        }
    }
    
    @ViewBuilder
    var standardBubble: some View {
        HStack(alignment: .top, spacing: 8) {
            if isUser {
                Spacer(minLength: 60)
            }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                if !isUser && toolUsed != nil && toolUsed != "context" && toolUsed != "suggestion" && toolUsed != "checklist_action" {
                    Text(toolLabel)
                        .font(.custom("DMSans-Medium", size: 12))
                        .foregroundColor(labelColor)
                }
                
                // Format text with markdown support
                if text.contains("**") || text.contains("•") {
                    FormattedTextView(text: text, isUser: isUser)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(backgroundColor)
                                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                        )
                } else {
                    Text(text)
                        .font(.custom("DMSans-Regular", size: 16))
                        .foregroundColor(isUser ? .white : .black)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(backgroundColor)
                                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                        )
                }
            }
            .frame(maxWidth: 300, alignment: isUser ? .trailing : .leading)
            /* Icon overlay disabled for now for cleaner alignment
            .overlay(
                Group {
                    if !isUser && toolUsed != nil && toolUsed != "context" && toolUsed != "suggestion" && toolUsed != "checklist_action" {
                        Image(systemName: iconName)
                            .font(.system(size: 18))
                            .foregroundColor(iconColor)
                            .background(Circle().fill(iconColor.opacity(0.1)).frame(width: 28, height: 28))
                            .offset(x: -10, y: -10)
                    }
                }, alignment: .topLeading
            )
            .padding(.leading, (!isUser && toolUsed != nil && toolUsed != "context" && toolUsed != "suggestion" && toolUsed != "checklist_action") ? 24 : 0)
            */

            if !isUser { Spacer(minLength: 60) }
        }
    }
    
    var backgroundColor: Color {
        if isUser {
            return Color.black
        } else if toolUsed == "suggestion" {
            return Color.blue.opacity(0.08)
        } else if toolUsed == "error" {
            return Color.red.opacity(0.08)
        } else {
            return Color.white
        }
    }
    
    var iconName: String {
        switch toolUsed {
        case "gear_recommendation_tool":
            return "backpack"
        case "wardrobe_inventory_tool":
            return "tshirt"
        case "trail_analysis_tool":
            return "chart.line.uptrend.xyaxis"
        case "chat_tool":
            return "bubble.left.and.bubble.right"
        case "error":
            return "exclamationmark.triangle"
        default:
            return "sparkles"
        }
    }
    
    var iconColor: Color {
        switch toolUsed {
        case "gear_recommendation_tool":
            return .green
        case "wardrobe_inventory_tool":
            return .purple
        case "trail_analysis_tool":
            return .orange
        case "chat_tool":
            return .blue
        case "error":
            return .red
        default:
            return .blue
        }
    }
    
    var labelColor: Color {
        return iconColor
    }
    
    var toolLabel: String {
        switch toolUsed {
        case "gear_recommendation_tool":
            return "Gear Recommendations"
        case "wardrobe_inventory_tool":
            return "Wardrobe Check"
        case "trail_analysis_tool":
            return "Trail Analysis"
        case "chat_tool":
            return "General Info"
        case "error":
            return "Error"
        default:
            return ""
        }
    }
}

// Helper view to format text with markdown-like styling
struct FormattedTextView: View {
    let text: String
    let isUser: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(parseText(), id: \.self) { section in
                if section.hasPrefix("**") && section.hasSuffix("**") {
                    // Bold headers
                    Text(section.replacingOccurrences(of: "**", with: ""))
                        .font(.custom("DMSans-SemiBold", size: 16))
                        .foregroundColor(isUser ? .white : .black)
                } else if section.hasPrefix("•") {
                    // Bullet points
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .font(.custom("DMSans-Regular", size: 16))
                            .foregroundColor(isUser ? .white.opacity(0.7) : .black.opacity(0.7))
                        Text(section.dropFirst(1).trimmingCharacters(in: .whitespaces))
                            .font(.custom("DMSans-Regular", size: 16))
                            .foregroundColor(isUser ? .white : .black)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else if section.hasPrefix("_") && section.hasSuffix("_") {
                    // Italic context
                    Text(section.replacingOccurrences(of: "_", with: ""))
                        .font(.custom("DMSans-Regular", size: 14))
                        .italic()
                        .foregroundColor(isUser ? .white.opacity(0.8) : .black.opacity(0.6))
                } else if !section.isEmpty {
                    // Regular text
                    Text(section)
                        .font(.custom("DMSans-Regular", size: 16))
                        .foregroundColor(isUser ? .white : .black)
                }
            }
        }
    }
    
    func parseText() -> [String] {
        // Split by newlines but keep the structure
        return text.components(separatedBy: "\n").filter { !$0.isEmpty }
    }
}

//#Preview{
//    MainTabView()
//}

