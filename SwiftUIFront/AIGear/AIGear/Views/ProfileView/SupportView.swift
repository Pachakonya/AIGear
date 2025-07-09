import SwiftUI

struct SupportView: View {
    var body: some View {
        ZStack {
            AuthBackgroundView(imageName: "support_image")
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 28) {
                    Spacer(minLength: 32)
                    
                    // Title
                    HStack(spacing: 8) {
                        Image("horse_icon")
                            .resizable()
                            .frame(width: 32, height: 32)
                        Text("AI : GEAR")
                            .font(.custom("DMMono-Regular", size: 24))
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.trailing, 16)
                    
                    // Subtitle
                    Text("I'm building an app for safe hiking - because I want traveling be more available and safe for beginners.")
                        .font(.custom("DMSans-Regular", size: 20))
                        .foregroundColor(.white.opacity(0.92))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                    // Card
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Our Social Media:")
                            .font(.headline)
                            .foregroundColor(.white)
                        VStack(spacing: 16) {
                            SupportSocialRow(icon: "camera.fill", color: .white.opacity(0.7), title: "Instagram", subtitle: "@sugirbaydastan", url: "https://www.instagram.com/sugirbaydastan/")
                            SupportSocialRow(icon: "link.circle.fill", color: .white.opacity(0.7), title: "LinkedIn", subtitle: "Dastan Sugirbay", url: "https://www.linkedin.com/in/dastan-sugirbay-545434292/")
                            SupportSocialRow(icon: "envelope.fill", color: .white.opacity(0.7), title: "Email", subtitle: "dastan.sugirbay@gmail.com", url: "mailto:dastan.sugirbay@gmail.com")
                        }
//                        Divider().background(Color.white.opacity(0.2))
//                        Text("A Small Request from the Heart:")
//                            .font(.headline)
//                            .foregroundColor(.white)
//                        VStack(spacing: 8) {
//                            
//                        }
//                        .padding(.top, 4)
                    }
                    .padding(.vertical, 28)
                    .padding(.horizontal, 20)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
                    .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                    .shadow(color: .black.opacity(0.18), radius: 16, x: 0, y: 8)
                    .padding(.horizontal, 16)
                    Spacer(minLength: 32)
                }
                .frame(maxWidth: 600)
                .padding(.vertical, 24)
            }
        }
    }
}

struct SupportSocialRow: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String
    let url: String
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(color)
                .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
            }
            Spacer()
            if let link = URL(string: url) {
                Link(destination: link) {
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 18))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.07))
        .cornerRadius(12)
    }
}

#Preview {
    SupportView()
}
