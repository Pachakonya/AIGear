import SwiftUI
import GoogleSignIn
import GoogleSignInSwift

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

                GoogleSignInButton(action: handleGoogleSignIn)
                    .frame(height: 50)
                    .padding()
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

    func handleGoogleSignIn() {
        guard let windowScene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }),
              let rootViewController = windowScene.windows
                .first(where: { $0.isKeyWindow })?.rootViewController else { return }
        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { signInResult, error in
            if let error = error {
                print("Google Sign-In error: \(error)")
                return
            }
            guard let idToken = signInResult?.user.idToken?.tokenString else {
                print("No Google ID token")
                return
            }
            // Send idToken to your backend
            Task {
                await AuthService.shared.signInWithGoogle(idToken: idToken)
            }
        }
    }
}

