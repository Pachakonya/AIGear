import SwiftUI

struct AuthBackgroundView: View {
    var imageName: String = "auth_image"
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                Image(imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .scaleEffect(1.2)
                    .offset(y: 20)
                    .offset(x: 100)
                    .ignoresSafeArea()
                    
                Color.black
                    .opacity(0.4)
                    .ignoresSafeArea()
            }
        }
    }
}
