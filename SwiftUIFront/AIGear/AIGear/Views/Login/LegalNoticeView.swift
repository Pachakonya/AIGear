import SwiftUI

struct LegalNoticeView: View {
    var onTOS: () -> Void
    var onPP: () -> Void

    var body: some View {
        Text(makeAttributedString())
            .font(.footnote)
            .foregroundColor(.white.opacity(0.7))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
            .onOpenURL { url in
                if url.absoluteString == "tos://" {
                    onTOS()
                } else if url.absoluteString == "pp://" {
                    onPP()
                }
            }
    }

    private func makeAttributedString() -> AttributedString {
        var str = AttributedString("By continuing you agree to our Terms of Service and Privacy Policy.")
        if let tosRange = str.range(of: "Terms of Service") {
            str[tosRange].foregroundColor = .white.opacity(0.7)
            str[tosRange].underlineStyle = .single
            str[tosRange].link = URL(string: "tos://")!
        }
        if let ppRange = str.range(of: "Privacy Policy") {
            str[ppRange].foregroundColor = .white.opacity(0.7)
            str[ppRange].underlineStyle = .single
            str[ppRange].link = URL(string: "pp://")!
        }
        return str
    }
}
