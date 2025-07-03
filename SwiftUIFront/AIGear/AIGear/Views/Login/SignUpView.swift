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

    var body: some View {
        GeometryReader { geo in
            ZStack {
                AuthBackgroundView()
                    .scaleEffect(1.3)

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
                                
                            Button("Verify") {
                                Task { await verify() }
                            }
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
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
                                
                            Button("Continue") {
                                Task { await signUp() }
                            }
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
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
                    
                    Text("By continuing you agree to our Terms of Service and Privacy Policy.")
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.bottom, geo.safeAreaInsets.bottom + 12)
                }
                .frame(width: geo.size.width)
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
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
                isVerifying = true
                print("✅ Registration successful. Please verify your email.")
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            print("❌ Sign-up error: \(error.localizedDescription)")
        }
    }

    func verify() async {
        do {
            let success = try await authService.verifyEmail(email: email, code: code)
            if success {
                print("✅ Verification complete. User authenticated.")
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            print("❌ Verification error: \(error.localizedDescription)")
        }
    }
}

