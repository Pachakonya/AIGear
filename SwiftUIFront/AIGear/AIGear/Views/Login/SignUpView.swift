import SwiftUI
import Clerk

struct SignUpView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var code = ""
    @State private var isVerifying = false
    @State private var isVerified = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Sign Up").font(.title)

                if isVerifying {
                    TextField("Verification Code", text: $code)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    Button("Verify") {
                        Task { await verify(code: code) }
                    }
                } else {
                    TextField("Email", text: $email)
                        .disableAutocorrection(true)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    SecureField("Password", text: $password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    Button("Continue") {
                        Task { await signUp(email: email, password: password) }
                    }
                }
            }
            .padding()
            
            .navigationDestination(isPresented: $isVerified) {
                MainTabView()
            }
        }
    }

    func signUp(email: String, password: String) async {
        do {
            var signUp = try await SignUp.create(
                strategy: .standard(emailAddress: email, password: password)
            )

            if signUp.unverifiedFields.contains("email_address") {
                signUp = try await signUp.prepareVerification(strategy: .emailCode)
                isVerifying = true
            }
        } catch {
            print("Sign-up error: \(error)")
        }
    }

    func verify(code: String) async {
        do {
            guard let signUp = Clerk.shared.client?.signUp else {
                isVerifying = false
                return
            }

            let result = try await signUp.attemptVerification(strategy: .emailCode(code: code))

            if result.status == .complete {
                // ✅ Session is automatically created by Clerk
                print("✅ Verification complete. Session created.")
                isVerified = true
            } else {
                print("⚠️ Verification pending. Status: \(result.status.rawValue)")
            }

        } catch {
            print("❌ Verification error: \(error.localizedDescription)")
        }
    }
}

