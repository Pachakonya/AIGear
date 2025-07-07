import SwiftUI

struct LegalNoticeView: View {
    var onTOS: () -> Void
    var onPP: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Text("By continuing to use AIGear, you agree to our")
                .font(.footnote)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
            HStack(spacing: 4) {
                Button(action: onTOS) {
                    Text("Terms of Service")
                        .font(.footnote)
                        .underline()
                        .foregroundColor(.white.opacity(0.7))
                }
                Text("and")
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.7))
                Button(action: onPP) {
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
        .padding(.bottom, 12)
    }
}