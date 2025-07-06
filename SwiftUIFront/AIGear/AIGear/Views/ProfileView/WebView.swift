import SwiftUI
import WebKit

struct WebView: UIViewRepresentable {
    let url: URL
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.load(URLRequest(url: url))
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        // No updates needed
    }
}

struct WebViewWithTitle: View {
    let title: String
    let url: URL
    
    var body: some View {
        NavigationView {
            WebView(url: url)
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
        }
    }
} 