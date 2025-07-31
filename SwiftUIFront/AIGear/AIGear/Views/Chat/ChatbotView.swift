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
    @Binding var selectedTab: Int
    
    @State private var chatHistory: [ChatMessage] = [
        ChatMessage(text: "Hi! I'm AI Gear Assistant. Ask me for gear suggestions, check your wardrobe, or just chat about hiking.", isUser: false)
    ]
    @State private var userInput: String = ""
    @State private var isLoading: Bool = false
    @FocusState private var isInputFocused: Bool
    @State private var shouldAutoScroll: Bool = true
    @State private var showScrollToBottomButton: Bool = false
    @State private var lastMessageWasFromUser: Bool = false
    
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
    
    // Map view state
    @State private var showGearRentalMap = false
    @State private var selectedBusiness: GearRentalBusiness?
    
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
                    ZStack(alignment: .bottomTrailing) {
                        ScrollView {
                            VStack(spacing: 12) {
                                ForEach(chatHistory) { message in
                                    ChatBubble(
                                        text: message.text,
                                        isUser: message.isUser,
                                        toolUsed: message.toolUsed,
                                        payload: message.payload,
                                        selectedBusiness: $selectedBusiness,
                                        showGearRentalMap: $showGearRentalMap,
                                        selectedTab: $selectedTab
                                    )
                                    .id(message.id)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                        }
                        .onChange(of: chatHistory.count) { _ in
                            // Always scroll to show user's own messages
                            if lastMessageWasFromUser {
                                withAnimation {
                                    proxy.scrollTo(chatHistory.last?.id, anchor: .bottom)
                                }
                                lastMessageWasFromUser = false
                            } else if shouldAutoScroll {
                                // Only auto-scroll for AI messages if user hasn't manually scrolled up
                                withAnimation {
                                    proxy.scrollTo(chatHistory.last?.id, anchor: .bottom)
                                }
                            } else {
                                // AI message arrived - create subtle upward shift to indicate new content
                                if chatHistory.count >= 3 {
                                    // Find a message a few positions back to create a gentle shift
                                    let shiftTargetIndex = max(0, chatHistory.count - 3)
                                    withAnimation(.easeInOut(duration: 0.4)) {
                                        proxy.scrollTo(chatHistory[shiftTargetIndex].id, anchor: .center)
                                    }
                                }
                                // Show scroll to bottom button when AI messages arrive
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    showScrollToBottomButton = true
                                }
                            }
                        }
                        
                        // Scroll to bottom button
                        if showScrollToBottomButton {
                            Button(action: {
                                withAnimation {
                                    proxy.scrollTo(chatHistory.last?.id, anchor: .bottom)
                                }
                                shouldAutoScroll = true
                                showScrollToBottomButton = false
                            }) {
                                Image(systemName: "arrow.down.circle.fill")
                                    .font(.system(size: 36))
                                    .foregroundColor(.white)
                                    .background(Color.black.opacity(0.7))
                                    .clipShape(Circle())
                                    .shadow(radius: 4)
                            }
                            .padding(.trailing, 16)
                            .padding(.bottom, 16)
                            .transition(.scale.combined(with: .opacity))
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
        
        // Mark that the next message will be from user (so we can scroll to show it)
        lastMessageWasFromUser = true
        
        // Disable auto-scroll for subsequent AI responses
        shouldAutoScroll = false
        
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
    @Binding var selectedBusiness: GearRentalBusiness?
    @Binding var showGearRentalMap: Bool
    @Binding var selectedTab: Int
    
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
                    FormattedTextView(
                        text: text, 
                        isUser: isUser,
                        selectedBusiness: $selectedBusiness,
                        showGearRentalMap: $showGearRentalMap,
                        selectedTab: $selectedTab
                    )
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
    @Binding var selectedBusiness: GearRentalBusiness?
    @Binding var showGearRentalMap: Bool
    @Binding var selectedTab: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(parseText().enumerated()), id: \.offset) { index, section in
                formatSection(section)
            }
        }
    }
    
    @ViewBuilder
    func formatSection(_ section: String) -> some View {
        if section.contains("🏪") && section.contains("**") {
            // Main title - clean and professional
            let cleanTitle = section.replacingOccurrences(of: "**", with: "").replacingOccurrences(of: "🏪 ", with: "")
            Text(cleanTitle)
                .font(.custom("DMSans-Bold", size: 18))
                .foregroundColor(isUser ? .white : .black)
                .padding(.bottom, 8)
            
        } else if section.contains("📍") {
            // Search area subtitle - minimal
            let cleanText = section.replacingOccurrences(of: "📍 Search area: ", with: "")
            Text(cleanText)
                .font(.custom("DMSans-Regular", size: 13))
                .foregroundColor(isUser ? .white.opacity(0.7) : .secondary)
                .padding(.bottom, 16)
            
        } else if section.hasPrefix("**") && (section.contains(". ") || section.contains("**")) && section.contains("🟢") {
            // Business card - professional design
            let cleanName = section
                .replacingOccurrences(of: "**", with: "")
                .replacingOccurrences(of: " 🟢", with: "")
            
            // Extract number and name
            let parts = cleanName.components(separatedBy: ". ")
            if parts.count >= 2 {
                VStack(alignment: .leading, spacing: 0) {
                    // Business header
                    HStack(spacing: 12) {
                        // Number in minimal style
                        Text(parts[0])
                            .font(.custom("DMSans-Bold", size: 16))
                            .foregroundColor(isUser ? .white.opacity(0.6) : .secondary)
                        
                        // Business name
                        Text(parts.dropFirst().joined(separator: ". "))
                            .font(.custom("DMSans-SemiBold", size: 17))
                            .foregroundColor(isUser ? .white : .black)
                        
                        Spacer()
                    }
                    .padding(.bottom, 8)
                    
                    // Separator line
                    Rectangle()
                        .fill(isUser ? Color.white.opacity(0.2) : Color.gray.opacity(0.3))
                        .frame(height: 1)
                        .padding(.bottom, 12)
                }
            }
            
        } else if section.hasPrefix("• **") {
            // Detail rows (Rating, Address, etc.)
            formatDetailRow(section)
            
        } else if section.hasPrefix("💡") {
            // Tips section header
            let cleanText = section.replacingOccurrences(of: "💡 ", with: "").replacingOccurrences(of: "**", with: "")
            VStack(alignment: .leading, spacing: 8) {
                Text(cleanText)
                    .font(.custom("DMSans-SemiBold", size: 16))
                    .foregroundColor(isUser ? .white : .primary)
                    .padding(.top, 16)
                
                Rectangle()
                    .fill(isUser ? Color.white.opacity(0.2) : Color.gray.opacity(0.3))
                    .frame(height: 1)
            }
            
        } else if section.hasPrefix("•") && !section.hasPrefix("• **") {
            // Tip bullet points - clean list style
            HStack(alignment: .top, spacing: 10) {
                Text("•")
                    .font(.custom("DMSans-Regular", size: 14))
                    .foregroundColor(isUser ? .white.opacity(0.5) : .secondary)
                    .padding(.top, 1)
                Text(section.dropFirst(1).trimmingCharacters(in: .whitespaces))
                    .font(.custom("DMSans-Regular", size: 14))
                    .foregroundColor(isUser ? .white.opacity(0.8) : .secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
            }
            .padding(.vertical, 1)
            
        } else if section.hasPrefix("**") && section.hasSuffix("**") {
            // Other bold headers
            Text(section.replacingOccurrences(of: "**", with: ""))
                .font(.custom("DMSans-Bold", size: 16))
                .foregroundColor(isUser ? .white : .black)
                .padding(.vertical, 4)
                
        } else if !section.isEmpty {
            // Regular text
            Text(section)
                .font(.custom("DMSans-Regular", size: 15))
                .foregroundColor(isUser ? .white : .black)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    @ViewBuilder
    func formatDetailRow(_ section: String) -> some View {
        // Parse detail rows like "• **Rating:** ⭐ 4.6/5 (638 reviews)"
        let content = section.dropFirst(2) // Remove "• "
        
        if content.hasPrefix("**Rating:**") {
            let ratingText = String(content.dropFirst(11)).trimmingCharacters(in: .whitespaces)
            HStack(spacing: 8) {
                Text("Rating")
                    .font(.custom("DMSans-Medium", size: 14))
                    .foregroundColor(isUser ? .white.opacity(0.7) : .secondary)
                    .frame(width: 60, alignment: .leading)
                Text(ratingText)
                    .font(.custom("DMSans-Regular", size: 14))
                    .foregroundColor(isUser ? .white : .primary)
                Spacer()
            }
            .padding(.vertical, 2)
            
        } else if content.hasPrefix("**Address:**") {
            HStack(spacing: 8) {
                Text("Location")
                    .font(.custom("DMSans-Medium", size: 14))
                    .foregroundColor(isUser ? .white.opacity(0.7) : .secondary)
                    .frame(width: 60, alignment: .leading)
                Button(action: {
                    print("🗺️ Show on Map button pressed for Address section")
                    
                    // Find coordinates specific to this business by looking for the nearest coordinates
                    // in the context of the current address line
                    let lines = text.components(separatedBy: "\n")
                    var foundCoordinates: CLLocationCoordinate2D?
                    
                    // Get the current address text to identify which business this is
                    let currentAddress = String(content.dropFirst(12)).trimmingCharacters(in: .whitespaces)
                    print("🏢 Looking for coordinates for address: '\(currentAddress)'")
                    
                    // Find the business section that contains this address
                    var businessSectionStart = -1
                    var businessSectionEnd = -1
                    
                    for (index, line) in lines.enumerated() {
                        if line.contains("**Address:**") && line.contains(currentAddress) {
                            // Found the address line, now find the business section boundaries
                            businessSectionStart = index
                            
                            // Look backwards to find the business name (starts with **1. or **2. etc)
                            for backIndex in stride(from: index, through: 0, by: -1) {
                                if lines[backIndex].hasPrefix("**") && (lines[backIndex].contains(". ") || lines[backIndex].contains("**")) && lines[backIndex].contains("🟢") {
                                    businessSectionStart = backIndex
                                    break
                                }
                            }
                            
                            // Look forwards to find the end (next business or end of text)
                            for forwardIndex in (index + 1)..<lines.count {
                                if lines[forwardIndex].hasPrefix("**") && (lines[forwardIndex].contains(". ") || lines[forwardIndex].contains("**")) && lines[forwardIndex].contains("🟢") {
                                    businessSectionEnd = forwardIndex - 1
                                    break
                                }
                            }
                            if businessSectionEnd == -1 {
                                businessSectionEnd = lines.count - 1
                            }
                            break
                        }
                    }
                    
                    print("🎯 Business section: lines \(businessSectionStart) to \(businessSectionEnd)")
                    
                    if businessSectionStart >= 0 && businessSectionEnd >= businessSectionStart {
                        // Search for coordinates only within this business section
                        for lineIndex in businessSectionStart...businessSectionEnd {
                            let line = lines[lineIndex]
                            
                            if line.contains("Maps:") {
                                print("🎯 Found Maps coordinate line in business section: '\(line)'")
                                
                                if let colonIndex = line.firstIndex(of: ":") {
                                    let coordText = String(line[line.index(after: colonIndex)...])
                                        .trimmingCharacters(in: .whitespaces)
                                        .replacingOccurrences(of: "**", with: "")
                                        .trimmingCharacters(in: .whitespaces)
                                    print("📍 Business-specific coordinates: '\(coordText)'")
                                    
                                    let coords = coordText.components(separatedBy: ",")
                                    if coords.count == 2,
                                       let lat = Double(coords[0].trimmingCharacters(in: .whitespaces)),
                                       let lng = Double(coords[1].trimmingCharacters(in: .whitespaces)) {
                                        foundCoordinates = CLLocationCoordinate2D(latitude: lat, longitude: lng)
                                        print("✅ Successfully parsed business coordinates: \(lat), \(lng)")
                                        break
                                    }
                                }
                            }
                        }
                    }
                    
                    if let coordinates = foundCoordinates {
                        print("🏪 Using coordinates for this specific business: \(coordinates.latitude), \(coordinates.longitude)")
                        
                        // Switch to Map tab
                        selectedTab = 0
                        
                        // Send notification to show pin at the exact coordinates from backend
                        NotificationCenter.default.post(name: .showPinAtLocation, object: coordinates)
                        
                        print("🎉 Switched to Map tab and showing pin at business-specific coordinates!")
                    } else {
                        print("❌ No coordinates found for this specific business")
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "map.fill")
                            .font(.system(size: 12))
                        Text("Show on Map")
                    }
                    .font(.custom("DMSans-Medium", size: 14))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue)
                    .cornerRadius(16)
                }
                Spacer()
            }
            .padding(.vertical, 2)
            
        } else if content.hasPrefix("**Status:**") {
            let statusText = String(content.dropFirst(11)).trimmingCharacters(in: .whitespaces)
            HStack(spacing: 8) {
                Text("Status")
                    .font(.custom("DMSans-Medium", size: 14))
                    .foregroundColor(isUser ? .white.opacity(0.7) : .secondary)
                    .frame(width: 60, alignment: .leading)
                Text(statusText)
                    .font(.custom("DMSans-Medium", size: 14))
                    .foregroundColor(statusText.contains("Open") ? .green : .orange)
                Spacer()
            }
            .padding(.vertical, 2)
            
        } else if content.hasPrefix("**Website:**") {
            let websiteText = String(content.dropFirst(12)).trimmingCharacters(in: .whitespaces)
            HStack(spacing: 8) {
                Text("Website")
                    .font(.custom("DMSans-Medium", size: 14))
                    .foregroundColor(isUser ? .white.opacity(0.7) : .secondary)
                    .frame(width: 60, alignment: .leading)
                Button(action: {
                    if let url = URL(string: websiteText) {
                        UIApplication.shared.open(url)
                    }
                }) {
                    Text(websiteText)
                        .font(.custom("DMSans-Regular", size: 14))
                        .foregroundColor(.blue)
                        .underline()
                        .multilineTextAlignment(.leading)
                }
                Spacer()
            }
            .padding(.vertical, 2)
            
        } else if content.hasPrefix("**Phone:**") {
            let phoneText = String(content.dropFirst(10)).trimmingCharacters(in: .whitespaces)
            HStack(spacing: 8) {
                Text("Phone")
                    .font(.custom("DMSans-Medium", size: 14))
                    .foregroundColor(isUser ? .white.opacity(0.7) : .secondary)
                    .frame(width: 60, alignment: .leading)
                Button(action: {
                    let cleanPhone = phoneText.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "(", with: "").replacingOccurrences(of: ")", with: "").replacingOccurrences(of: "-", with: "")
                    if let url = URL(string: "tel:\(cleanPhone)") {
                        UIApplication.shared.open(url)
                    }
                }) {
                    Text(phoneText)
                        .font(.custom("DMSans-Regular", size: 14))
                        .foregroundColor(.blue)
                        .underline()
                }
                Spacer()
            }
            .padding(.vertical, 2)
            
        } else if content.hasPrefix("**Coordinates:**") {
            // Hide coordinates from user - they're only for internal map integration
            EmptyView()
            
        } else if content.hasPrefix("**Google Maps:**") {
            // Hide old Google Maps entries completely
            EmptyView()
            
        } else if content.hasPrefix("**Maps:**") {
            let coordinatesText = String(content.dropFirst(9)).trimmingCharacters(in: .whitespaces)
            HStack(spacing: 8) {
                Text("Maps")
                    .font(.custom("DMSans-Medium", size: 14))
                    .foregroundColor(isUser ? .white.opacity(0.7) : .secondary)
                    .frame(width: 60, alignment: .leading)
                Button(action: {
                    // Parse coordinates and show in-app map
                    let coords = coordinatesText.components(separatedBy: ",")
                    if coords.count == 2,
                       let lat = Double(coords[0].trimmingCharacters(in: .whitespaces)),
                       let lng = Double(coords[1].trimmingCharacters(in: .whitespaces)) {
                        
                        // Extract business info from the current text context
                        // This is a simplified approach - in production you might want to pass this data differently
                        let businessInfo = extractBusinessInfo(from: text, coordinates: CLLocationCoordinate2D(latitude: lat, longitude: lng))
                        selectedBusiness = businessInfo
                        showGearRentalMap = true
                    }
                }) {
                    Text("View on Map")
                        .font(.custom("DMSans-Regular", size: 14))
                        .foregroundColor(.blue)
                        .underline()
                }
                Spacer()
            }
            .padding(.vertical, 2)
            
        } else {
            // Fallback for other detail rows
            HStack(alignment: .top, spacing: 8) {
                Text("•")
                    .font(.custom("DMSans-Regular", size: 14))
                    .foregroundColor(isUser ? .white.opacity(0.6) : .gray)
                    .padding(.top, 2)
                Text(String(content))
                    .font(.custom("DMSans-Regular", size: 14))
                    .foregroundColor(isUser ? .white.opacity(0.8) : .secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
    
    func parseText() -> [String] {
        // Split by newlines but keep the structure
        return text.components(separatedBy: "\n").filter { !$0.isEmpty }
    }
    
    func extractBusinessInfo(from text: String, coordinates: CLLocationCoordinate2D) -> GearRentalBusiness {
        let lines = text.components(separatedBy: "\n")
        var businessName = "Business"
        var address = "Address not available"
        var website: String? = nil
        var phone: String? = nil
        var rating: String? = nil
        
        for line in lines {
            if line.contains("**") && (line.contains(". ") || line.contains("**")) && line.contains("🟢") {
                // Extract business name
                let cleanName = line
                    .replacingOccurrences(of: "**", with: "")
                    .replacingOccurrences(of: " 🟢", with: "")
                let parts = cleanName.components(separatedBy: ". ")
                if parts.count >= 2 {
                    businessName = parts.dropFirst().joined(separator: ". ")
                }
            } else if line.contains("**Address:**") {
                address = String(line.dropFirst(line.firstIndex(of: ":") != nil ? line.distance(from: line.startIndex, to: line.firstIndex(of: ":")!) + 1 : 0))
                    .trimmingCharacters(in: .whitespaces)
                    .replacingOccurrences(of: "**Address:** ", with: "")
            } else if line.contains("**Website:**") {
                website = String(line.dropFirst(line.firstIndex(of: ":") != nil ? line.distance(from: line.startIndex, to: line.firstIndex(of: ":")!) + 1 : 0))
                    .trimmingCharacters(in: .whitespaces)
                    .replacingOccurrences(of: "**Website:** ", with: "")
            } else if line.contains("**Phone:**") {
                phone = String(line.dropFirst(line.firstIndex(of: ":") != nil ? line.distance(from: line.startIndex, to: line.firstIndex(of: ":")!) + 1 : 0))
                    .trimmingCharacters(in: .whitespaces)
                    .replacingOccurrences(of: "**Phone:** ", with: "")
            } else if line.contains("**Rating:**") {
                rating = String(line.dropFirst(line.firstIndex(of: ":") != nil ? line.distance(from: line.startIndex, to: line.firstIndex(of: ":")!) + 1 : 0))
                    .trimmingCharacters(in: .whitespaces)
                    .replacingOccurrences(of: "**Rating:** ", with: "")
            }
        }
        
        return GearRentalBusiness(
            name: businessName,
            address: address,
            coordinate: coordinates,
            website: website,
            phone: phone,
            rating: rating
        )
    }
}

// MARK: - Supporting Data Structures
struct GearRentalBusiness {
    let name: String
    let address: String
    let coordinate: CLLocationCoordinate2D
    let website: String?
    let phone: String?
    let rating: String?
}

//#Preview{
//    MainTabView()
//}

