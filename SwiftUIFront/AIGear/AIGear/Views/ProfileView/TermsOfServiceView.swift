import SwiftUI

struct TermsOfServiceView: View {
    // Production URL
    private let termsOfServiceURL = URL(string: "https://api.aigear.tech/terms-of-service")!
    
    var body: some View {
        WebViewWithTitle(title: "Terms of Service", url: termsOfServiceURL)
            .onAppear {
                print("TermsOfServiceView appeared with URL: \(termsOfServiceURL)")
            }
    }
}