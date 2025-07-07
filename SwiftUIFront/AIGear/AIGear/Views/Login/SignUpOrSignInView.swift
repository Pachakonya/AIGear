import SwiftUI
import GoogleSignIn
import GoogleSignInSwift
import AuthenticationServices

struct SignUpOrSignInView: View {
    @State private var showSignIn = false
    @State private var showSignUp = false
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showError = false
    @State private var showTermsOfService = false
    @State private var showPrivacyPolicy = false
    @State private var appleSignInCoordinator = AppleSignInCoordinator()
    @StateObject private var viewModel = AuthOptionsViewModel()
    
    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ZStack {
                    AuthBackgroundView()

                    VStack(spacing: 28) {
                        Spacer(minLength: geo.size.height * 0.08)

                        // Branded icon placeholder (replace with your asset)
//                        Image("horse_icon") // e.g., "dog_icon" or "hiking_icon"
//                            .resizable()
//                            .scaledToFit()
//                            .frame(width: 80, height: 80)
//                            .shadow(radius: 8, y: 4)

                        // Title
                        Text("Sign up or log in\nto access your profile")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .shadow(color: .black.opacity(0.7), radius: 4, x: 0, y: 2)
                            .padding(.horizontal, 16)

                        // Login card with blur and buttons
                        VStack(spacing: 20) {
                            // Apple Sign-In Button
                            Button(action: {
                                viewModel.handleAppleSignIn { success in
                                    // Optionally handle completion
                                }
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: "apple.logo")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 24, height: 24)
                                        .foregroundColor(.black)
                                    
                                    Text("Continue with Apple")
                                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                                        .foregroundColor(.black)
                                }
                                .frame(height: 52)
                                .frame(maxWidth: .infinity)
                                .background(.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
                            }
                            .padding(.horizontal, 8)

                            // Google Sign-In Button
                            Button(action: {
                                guard let windowScene = UIApplication.shared.connectedScenes
                                        .compactMap({ $0 as? UIWindowScene })
                                        .first(where: { $0.activationState == .foregroundActive }),
                                      let rootViewController = windowScene.windows
                                        .first(where: { $0.isKeyWindow })?.rootViewController else { return }
                                viewModel.handleGoogleSignIn(presentingViewController: rootViewController) { success in
                                    // Optionally handle completion
                                }
                            }) {
                                HStack(spacing: 12) {
                                    Image("g_logo") // Add a Google logo PNG to your assets
                                        .resizable()
                                        .frame(width: 24, height: 24)
                                    
                                    Text("Continue with Google")
                                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                                        .foregroundColor(.black)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
                            }
                            .padding(.horizontal, 8)

                            // Separator with "or"
                            HStack {
                                Rectangle()
                                    .frame(height: 1)
                                    .foregroundColor(.white.opacity(0.25))
                                Text("or")
                                    .foregroundColor(.white.opacity(0.7))
                                    .font(.subheadline)
                                    .padding(.horizontal, 8)
                                Rectangle()
                                    .frame(height: 1)
                                    .foregroundColor(.white.opacity(0.25))
                            }
                            .padding(.horizontal, 8)

                            // Continue with Email Button
                            Button(action: { showSignIn = true }) {
                                Text("Continue with email")
                                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                                    .foregroundColor(.black)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                    .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
                            }
                            .padding(.horizontal, 8)

                            // Sign Up link
                            Button(action: { showSignUp = true }) {
                                Text("Don't have an account? Sign Up")
                                    .font(.system(size: 16, weight: .medium, design: .rounded))
                                    .foregroundColor(.white.opacity(0.85))
                                    .underline()
                            }
                            .padding(.top, 4)
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

                    // Overlay the legal notice at the bottom
                    VStack {
                        Spacer()
                        VStack {
                            Text("By continuing to use AIGear, you agree to our")
                                .font(.footnote)
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                            HStack(spacing: 4) {
                                Button(action: { showTermsOfService = true }) {
                                    Text("Terms of Service")
                                        .font(.footnote)
                                        .underline()
                                        .foregroundColor(.white.opacity(0.7))
                                }
                                Text("and")
                                    .font(.footnote)
                                    .foregroundColor(.white.opacity(0.7))
                                Button(action: { showPrivacyPolicy = true }) {
                                    Text("Privacy Policy")
                                        .font(.footnote)
                                        .underline()
                                        .foregroundColor(.white.opacity(0.7))
                                }
                                Text(".")
                                    .font(.footnote)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, geo.safeAreaInsets.bottom + 12)
                    }
                }
                .navigationDestination(isPresented: $showSignIn) {
                    SignInView()
                        .navigationBarBackButtonHidden(false)
                        .navigationBarTitleDisplayMode(.inline)
                }
                .navigationDestination(isPresented: $showSignUp) {
                    SignUpView()
                        .navigationBarBackButtonHidden(false)
                        .navigationBarTitleDisplayMode(.inline)
                }
                .alert("Error", isPresented: $viewModel.showError) {
                    Button("OK") { viewModel.showError = false }
                } message: {
                    Text(viewModel.errorMessage ?? "")
                }
                // Present TOS and PP as sheets
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
        }
        .tint(.black)
    }
}

#Preview {
    SignUpOrSignInView()
}
