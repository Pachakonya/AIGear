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
        NavigationStack {
            VStack(spacing: 16) {
                Text("Sign Up").font(.title)

                if isVerifying {
                    TextField("Verification Code", text: $code)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    Button("Verify") {
                        Task { await verify() }
                    }
                    .disabled(authService.isLoading)
                } else {
                    TextField("Email", text: $email)
                        .disableAutocorrection(true)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    TextField("Username (Optional)", text: $username)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    SecureField("Password", text: $password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Button("Continue") {
                        Task { await signUp() }
                    }
                    .disabled(authService.isLoading)
                }
                
                if authService.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                }
            }
            .padding()
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

