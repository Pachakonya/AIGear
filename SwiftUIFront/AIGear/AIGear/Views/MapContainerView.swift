import SwiftUI

struct MapContainerView: View {
    @StateObject private var viewModel = MapViewModel()

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            MapboxOutdoorMapView(viewModel: viewModel)

            Button(action: {
                if let coordinate = viewModel.userLocation?.coordinate {
                    NotificationCenter.default.post(name: .centerMapExternally, object: coordinate)
                }
            }) {
                Image(systemName: "location.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.black)
                    .padding()
                    .background(Color.white)
                    .clipShape(Circle())
                    .shadow(radius: 4)
            }
            .padding(.bottom, 20)
            .padding(.trailing, 20)
        }
    }
}

