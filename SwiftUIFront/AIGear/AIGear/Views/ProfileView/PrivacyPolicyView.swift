import SwiftUI

struct PrivacyPolicyView: View {
    // Update this URL to match your backend server address
    private let privacyPolicyURL = URL(string: "http://aigear.tech/privacy-policy")!
    
    var body: some View {
        WebViewWithTitle(title: "Privacy Policy", url: privacyPolicyURL)
    }
}