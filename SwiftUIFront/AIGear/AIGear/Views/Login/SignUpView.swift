import SwiftUI

struct SignUpView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var username = ""
    @State private var code = ""
    @State private var isVerifying = false
    @State private var errorMessage = ""
    @State private var showError = false
    @StateObject private var authService = AuthService.shared
    @State private var showTermsOfService = false
    @State private var showPrivacyPolicy = false

    var body: some View {
        ZStack {
            AuthBackgroundView()
                .ignoresSafeArea()
            GeometryReader { geo in
                ZStack {
                    VStack(spacing: 28) {
                        Spacer(minLength: geo.size.height * 0.08)
                        // Branded icon (optional)
                        // Image("horse_icon")
                        //     .resizable()
                        //     .scaledToFit()
                        //     .frame(width: 80, height: 80)
                        //     .shadow(radius: 8, y: 4)
                        // Title
                        Text("Sign Up")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .shadow(color: .black.opacity(0.7), radius: 4, x: 0, y: 2)
                            .padding(.horizontal, 16)
                        // Card
                        VStack(spacing: 20) {
                            if isVerifying {
                                TextField("Verification Code", text: $code)
                                    .padding()
                                    .background(Color.white.opacity(0.9))
                                    .cornerRadius(12)
                                    .foregroundColor(.black)
                                    
                                Button(action: {
                                    Task { await verify() }
                                }) {
                                    Text("Verify")
                                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                                        .foregroundColor(.black)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(Color.white)
                                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                        .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
                                }
                                .disabled(authService.isLoading)
                            } else {
                                TextField("Email", text: $email)
                                    .disableAutocorrection(true)
                                    .keyboardType(.emailAddress)
                                    .textInputAutocapitalization(.never)
                                    .padding()
                                    .background(Color.white.opacity(0.9))
                                    .cornerRadius(12)
                                    .foregroundColor(.black)

                                TextField("Username (Optional)", text: $username)
                                    .padding()
                                    .background(Color.white.opacity(0.9))
                                    .cornerRadius(12)
                                    .foregroundColor(.black)

                                SecureField("Password", text: $password)
                                    .padding()
                                    .background(Color.white.opacity(0.9))
                                    .cornerRadius(12)
                                    .foregroundColor(.black)
                                    
                                Button(action: {
                                    Task { await signUp() }
                                }) {
                                    Text("Continue")
                                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                                        .foregroundColor(.black)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(Color.white)
                                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                        .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
                                }
                                .disabled(authService.isLoading)
                            }
                            if authService.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                            }
                        }
                        .padding(.vertical, 28)
                        .padding(.horizontal, 20)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
                        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                        .shadow(color: .black.opacity(0.18), radius: 16, x: 0, y: 8)
                        .padding(.horizontal, 16)
                        
                        Spacer()
                    }
                    .frame(width: geo.size.width)
                    .padding(.bottom, 60)
                }
            }
        }
        .overlay(
            VStack {
                Spacer()
                LegalNoticeView(
                    onTOS: { showTermsOfService = true },
                    onPP: { showPrivacyPolicy = true }
                )
                .padding(.bottom, 12)
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
        )
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .fullScreenCover(isPresented: $showTermsOfService) {
            NavigationView {
                TermsOfServiceView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { showTermsOfService = false }
                        }
                    }
            }
        }
        .fullScreenCover(isPresented: $showPrivacyPolicy) {
            NavigationView {
                PrivacyPolicyView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { showPrivacyPolicy = false }
                        }
                    }
            }
        }
    }

    func signUp() async {
        do {
            let success = try await authService.signUp(
                email: email, 
                password: password, 
                username: username.isEmpty ? nil : username
            )
            if success {
                // Send verification code after successful registration
                let codeSent = try await authService.sendVerificationCode(email: email)
                if codeSent {
                    isVerifying = true
                    // print("✅ Registration successful. Verification code sent. Please check your email.")
                } else {
                    errorMessage = "Failed to send verification code."
                    showError = true
                }
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func verify() async {
        do {
            let success = try await authService.verifyCode(email: email, code: code)
            if success {
                // ✅ After verification, log in and store token
                let loginSuccess = try await authService.signIn(email: email, password: password)
                if loginSuccess {
                    authService.isAuthenticated = true
                    // Optionally, navigate to the main app screen
                }
            } else {
                errorMessage = "Invalid or expired verification code."
                showError = true
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

