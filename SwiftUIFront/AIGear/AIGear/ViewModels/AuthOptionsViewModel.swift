import Foundation
import AuthenticationServices
import GoogleSignIn

class AppleSignInCoordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    var onSignIn: ((Result<ASAuthorizationAppleIDCredential, Error>) -> Void)?

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        // Use the key window for presentation
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            onSignIn?(.success(appleIDCredential))
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        onSignIn?(.failure(error))
    }
}

class AuthOptionsViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false

    // For Apple Sign-In
    let appleSignInCoordinator = AppleSignInCoordinator()

    func handleAppleSignIn(completion: @escaping (Bool) -> Void) {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = appleSignInCoordinator
        controller.presentationContextProvider = appleSignInCoordinator

        appleSignInCoordinator.onSignIn = { (result: Result<ASAuthorizationAppleIDCredential, Error>) in
            switch result {
            case .success(let credential):
                // Here you would send credential.identityToken to your backend for verification
                AuthService.shared.isAuthenticated = true
                print("Apple sign in success: \(credential)")
                completion(true)
            case .failure(let error):
                print("Apple sign in failed: \(error.localizedDescription)")
                self.errorMessage = error.localizedDescription
                self.showError = false
                completion(false)
            }
        }

        controller.performRequests()
    }

    func handleGoogleSignIn(presentingViewController: UIViewController, completion: @escaping (Bool) -> Void) {
        isLoading = true
        GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController) { signInResult, error in
            self.isLoading = false
            if let error = error {
                // Check for user cancellation (GoogleSignIn error code -5 or use NSError)
                let nsError = error as NSError
                if nsError.code == -5 { // -5 is user cancellation for GoogleSignIn
                    // Do nothing, just return
                    completion(false)
                    return
                }
                self.errorMessage = "Google Sign-In error: \(error.localizedDescription)"
                self.showError = true
                completion(false)
                return
            }
            guard let idToken = signInResult?.user.idToken?.tokenString else {
                self.errorMessage = "No Google ID token"
                self.showError = true
                completion(false)
                return
            }
            Task {
                await AuthService.shared.signInWithGoogle(idToken: idToken)
                completion(true)
            }
        }
    }
}
