import SwiftUI

struct PrivacyPolicyView: View {
    // Production URL
    private let privacyPolicyURL = URL(string: "https://aigear.tech/privacy-policy")!
    
    var body: some View {
        WebViewWithTitle(title: "Privacy Policy", url: privacyPolicyURL)
            .onAppear {
                print("PrivacyPolicyView appeared with URL: \(privacyPolicyURL)")
            }
    }
}