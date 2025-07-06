import SwiftUI

struct TermsOfServiceView: View {
    // Update this URL to match your backend server address
    private let termsOfServiceURL = URL(string: "http://aigear.tech/terms-of-service")!
    
    var body: some View {
        WebViewWithTitle(title: "Terms of Service", url: termsOfServiceURL)
    }
}