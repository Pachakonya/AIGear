import SwiftUI

struct HomeView: View {
    @State private var recommendations: [String] = []
    @State private var errorMessage: String?

    var body: some View {
        VStack {
            Button("Get Gear") {
                NetworkService.shared.getGearRecommendation(weather: "rainy", trailCondition: "rocky") { result in
                    DispatchQueue.main.async {
                        switch result {
                        case .success(let response):
                            recommendations = response.recommendations
                        case .failure(let error):
                            errorMessage = error.localizedDescription
                        }
                    }
                }
            }

            if let error = errorMessage {
                Text("Error: \(error)").foregroundColor(.red)
            }

            List(recommendations, id: \.self) { item in
                Text(item)
            }
        }
        .padding()
    }
}

