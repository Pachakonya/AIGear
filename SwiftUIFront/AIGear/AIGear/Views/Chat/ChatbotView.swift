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
                // Chat messages
                ScrollViewReader { scrollProxy in
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(chatHistory) { message in
                                HStack {
                                    if message.isUser { Spacer() }
                                    Text(message.text)
                                        .padding(.vertical, 10)
                                        .padding(.horizontal, 16)
                                        .background(
                                            message.isUser
                                            ? Color.accentColor
                                            : Color.white.opacity(0.85)
                                        )
                                        .foregroundColor(message.isUser ? .white : .black)
                                        .font(.system(size: 16, weight: .regular, design: .rounded))
                                        .cornerRadius(18)
                                        .shadow(color: .black.opacity(0.07), radius: 2, x: 0, y: 2)
                                    if !message.isUser { Spacer() }
                                }
                                .padding(.horizontal, 6)
                            }
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .accentColor))
                                    .frame(maxWidth: .infinity, alignment: .center)
                            }
                        }
                        .padding(.vertical, 12)
                    }
                    .background(Color.clear)
                }
                // Input bar
                HStack(spacing: 8) {
                    TextField("Type your message...", text: $userInput)
                        .font(.system(size: 16, weight: .regular, design: .rounded))
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .background(Color.white.opacity(0.9))
                        .cornerRadius(20)
                        .focused($isInputFocused)
                        .submitLabel(.send)
                        .onSubmit { sendMessage() }
                    Button(action: sendMessage) {
                        Image(systemName: "paperplane.fill")
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.accentColor)
                            .clipShape(Circle())
                    }
                    .disabled(userInput.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
                .cornerRadius(24)
                .padding(.bottom, 32) // <-- Extra space for TabBar
            }
            .padding(.top, 8)
            .padding(.bottom, 0)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            UIApplication.shared.endEditing()
        }
        // Only ignore keyboard for bottom safe area
        // .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    func sendMessage() {
        guard !userInput.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let userMsg = ChatMessage(text: userInput, isUser: true)
        chatHistory.append(userMsg)
        isLoading = true
        let prompt = userInput.lowercased()
        userInput = ""
        isInputFocused = false
        
        fetchGearAndHikeSuggestions(for: prompt)
    }

    func fetchGearAndHikeSuggestions(for prompt: String) {
        NetworkService.shared.getGearAndHikeSuggestions(prompt: prompt) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let decoded):
                    let gearText = "🧢 Gear Suggestions:\n" + decoded.gear.map { "• \($0)" }.joined(separator: "\n")
                    let hikeText = "🥾 Hike Tips:\n" + decoded.hike.map { "• \($0)" }.joined(separator: "\n")
                    let suggestion = "\n\nDo you want me to create a checklist for your hike?"
                    chatHistory.append(ChatMessage(text: gearText + "\n\n" + hikeText + suggestion, isUser: false))
                case .failure(let error):
                    chatHistory.append(ChatMessage(text: "Error: \(error.localizedDescription)", isUser: false))
                }
            }
        }
    }
}

#Preview{
    ChatbotView()
}

