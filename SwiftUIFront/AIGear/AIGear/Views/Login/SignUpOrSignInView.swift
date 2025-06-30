import SwiftUI

struct SignUpOrSignInView: View {
    @State private var isSignUp = true

    var body: some View {
        VStack {
            if isSignUp {
                SignUpView()
            } else {
                SignInView()
            }

            Button(action: {
                isSignUp.toggle()
            }) {
                Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                    .foregroundColor(.blue)
            }
            .padding()
        }
    }
}

