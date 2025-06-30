import SwiftUI
import Clerk

struct SignInView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var isSignedIn = false

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
                    Task { await signIn(email: email, password: password) }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .navigationDestination(isPresented: $isSignedIn) {
                MainTabView()
            }
        }
    }

    func signIn(email: String, password: String) async {
        do {
            let signIn = try await SignIn.create(
                strategy: .identifier(email, password: password)
            )

            if signIn.status == .complete {
                // ✅ Session is created automatically by Clerk
                isSignedIn = true
                print("✅ Signed in successfully")
            } else {
                print("⚠️ Sign-in incomplete. Status: \(signIn.status.rawValue)")
                // You could handle MFA, pending verification, etc. here
            }

        } catch {
            print("❌ Sign-in error: \(error.localizedDescription)")
        }
    }
}

