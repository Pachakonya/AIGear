import SwiftUI
import CoreLocation

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
    
    // Location services
    @StateObject private var locationService = LocationService()
    
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
                        .padding(.horizontal)
                        .padding(.vertical, 8)
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
                    
                    // Show send button when there's text, preference button when input is empty
                    if !userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        // Send button when there's text in input
                        Button(action: {
                            sendMessage()
                        }) {
                            Image(systemName: "arrow.up")
                                .foregroundColor(.white)
                                .frame(width: 40, height: 40)
                                .background(Color.black)
                                .clipShape(Circle())
                        }
                        .disabled(isLoading)
                    } else {
                        // Trip-spec settings button when input is empty
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
                }
                .padding(.horizontal)
                .padding(.vertical, 20)
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
                let summary = "Trip details: \(tripDays) day(s), \(overnightText), season: \(tripSeason.capitalized), companions: \(tripCompanions)"
                chatHistory.append(ChatMessage(text: summary, isUser: false, toolUsed: "context"))
                
                tripCustomized = true // mark as customized
            }
        }
        .onTapGesture {
            isInputFocused = false
        }
        .onAppear {
            // Request location permission and start location updates when chat view appears
            locationService.requestPermission()
            
            // Start location updates if already authorized
            if locationService.authorizationStatus == .authorizedWhenInUse || 
               locationService.authorizationStatus == .authorizedAlways {
                locationService.startUpdatingLocation()
            }
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
                text: "ℹ️ Tip: For more tailored gear suggestions, tap the slider icon to fill in trip details like days, season, and if you'll be overnighting.",
                isUser: false,
                toolUsed: "suggestion"
            ))
            tripReminderShown = true
        }
        
        // Call orchestrator
        callOrchestrator(for: trimmedInput)
    }
    
    func callOrchestrator(for prompt: String) {
        // Check if this might be a location-based request (more specific keywords)
        let lowercasedPrompt = prompt.lowercased()
        let locationKeywords = ["nearby", "near me", "close to me", "around here", "in my area"]
        let rentalKeywords = ["rental", "rent gear", "rent equipment"]
        
        let isLocationBasedRequest = locationKeywords.contains { lowercasedPrompt.contains($0) } ||
                                   rentalKeywords.contains { lowercasedPrompt.contains($0) }
        
        // If it's a location-based request, ensure location services are active
        if isLocationBasedRequest {
            // Start location updates if not already running
            if locationService.authorizationStatus == .authorizedWhenInUse || 
               locationService.authorizationStatus == .authorizedAlways {
                locationService.startUpdatingLocation()
                // Also request a one-time location update for immediate use
                locationService.requestLocationOnce()
            } else {
                // Request permission if not granted
                locationService.requestPermission()
            }
        }
        
        var userLocation: CLLocation? = nil
        
        // For location-based requests, try to get current location
        if isLocationBasedRequest {
            userLocation = locationService.currentLocation
            
            // Debug: Print location status
            print("🔍 Location Debug:")
            print("   Authorization: \(locationService.authorizationStatus?.rawValue ?? -1)")
            print("   Current Location: \(userLocation?.coordinate.latitude ?? 0), \(userLocation?.coordinate.longitude ?? 0)")
            print("   Location Available: \(userLocation != nil)")
            
            // If location is not available but request is location-based, show helpful message
            if userLocation == nil {
                // Check authorization status
                if locationService.authorizationStatus == .denied || locationService.authorizationStatus == .restricted {
                    chatHistory.append(ChatMessage(
                        text: "📍 Location access is needed for nearby searches. Please enable location permissions in Settings > Privacy & Security > Location Services > AI Gear.",
                        isUser: false,
                        toolUsed: "suggestion"
                    ))
                    isLoading = false
                    return
                } else if locationService.authorizationStatus == .notDetermined {
                    chatHistory.append(ChatMessage(
                        text: "📍 I need location permission to find nearby gear rental places. Please allow location access when prompted.",
                        isUser: false,
                        toolUsed: "suggestion"
                    ))
                    isLoading = false
                    return
                } else {
                    // Location is authorized but not available yet - give it a moment
                    chatHistory.append(ChatMessage(
                        text: "📍 Getting your location... This may take a moment.",
                        isUser: false,
                        toolUsed: "suggestion"
                    ))
                    
                    // Try to get location with a slight delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        if let delayedLocation = locationService.currentLocation {
                            print("🔍 Delayed location found: \(delayedLocation)")
                            NetworkService.shared.callOrchestrator(prompt: prompt, userLocation: delayedLocation) { result in
                                DispatchQueue.main.async {
                                    self.isLoading = false
                                    switch result {
                                    case .success(let response):
                                        self.structureOrchestratorResponse(response)
                                    case .failure(let error):
                                        self.chatHistory.append(ChatMessage(
                                            text: "Error: \(error.localizedDescription)",
                                            isUser: false,
                                            toolUsed: "error"
                                        ))
                                    }
                                }
                            }
                        } else {
                            self.chatHistory.append(ChatMessage(
                                text: "📍 Unable to get your current location. Please specify a city or area (e.g., 'Seattle, WA') for gear rental search.",
                                isUser: false,
                                toolUsed: "suggestion"
                            ))
                            self.isLoading = false
                        }
                    }
                    return
                }
            }
        }
        
        NetworkService.shared.callOrchestrator(prompt: prompt, userLocation: userLocation) { result in
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
        } else if response.tool_used == "hiking_plan_tool" {
            // Add hiking plan as one message
            chatHistory.append(ChatMessage(
                text: responseText,
                isUser: false,
                toolUsed: response.tool_used
            ))
        } else if response.tool_used == "gear_rental_tool" {
            // Add gear rental locations as one message
            chatHistory.append(ChatMessage(
                text: responseText,
                isUser: false,
                toolUsed: response.tool_used
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
        case "hiking_plan_tool":
            return "calendar.badge.clock"
        case "gear_rental_tool":
            return "storefront"
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
        case "hiking_plan_tool":
            return .indigo
        case "gear_rental_tool":
            return .brown
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
        case "hiking_plan_tool":
            return "Hiking Plan"
        case "gear_rental_tool":
            return "Gear Rentals"
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
            ForEach(Array(parseText().enumerated()), id: \.offset) { index, section in
                if section.contains("**") && (section.hasSuffix(":") || section.hasSuffix(":**")) {
                    // Bold headers (like **Clothing:** or **Equipment:**)
                    let cleanedText = section.replacingOccurrences(of: "**", with: "")
                    HStack(alignment: .center, spacing: 8) {
                        // Extract emoji if present
                        let parts = cleanedText.components(separatedBy: " ")
                        if parts.count > 1 && parts[0].count <= 2 {
                            // First part might be emoji
                            Text(parts[0])
                                .font(.system(size: 18))
                            Text(parts.dropFirst().joined(separator: " "))
                                .font(.custom("DMSans-Bold", size: 16))
                                .foregroundColor(isUser ? .white : .black)
                        } else {
                            Text(cleanedText)
                                .font(.custom("DMSans-Bold", size: 16))
                                .foregroundColor(isUser ? .white : .black)
                        }
                        Spacer()
                    }
                    .padding(.top, 4)
                } else if section.hasPrefix("**") && section.hasSuffix("**") {
                    // Other bold text
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

