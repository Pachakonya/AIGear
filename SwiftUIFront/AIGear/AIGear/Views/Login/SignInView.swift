import SwiftUI

struct SignInView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage = ""
    @State private var showError = false
    @StateObject private var authService = AuthService.shared

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Sign In").font(.title)

                TextField("Email", text: $email)
                    .disableAutocorrection(true)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .textFieldStyle(.roundedBorder)
                
                SecureField("Password", text: $password)
                    .textFieldStyle(.roundedBorder)

                Button("Continue") {
                    Task { await signIn() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(authService.isLoading)
                
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

    func signIn() async {
        do {
            let success = try await authService.signIn(email: email, password: password)
            if success {
                print("✅ Signed in successfully")
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            print("❌ Sign-in error: \(error.localizedDescription)")
        }
    }
}

