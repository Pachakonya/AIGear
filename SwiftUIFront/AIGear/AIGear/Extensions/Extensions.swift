import UIKit
import Combine

extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

extension UIApplication {
    func endEditing() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

struct WebLink: Identifiable {
    let id = UUID()
    let url: URL
    let title: String
}

class KeyboardObserver: ObservableObject {
    static let shared = KeyboardObserver() // Singleton instance

    @Published var isKeyboardVisible: Bool = false
    private var cancellables: Set<AnyCancellable> = []

    private init() { // Make init private to enforce singleton
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
            .sink { [weak self] _ in self?.isKeyboardVisible = true }
            .store(in: &cancellables)
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
            .sink { [weak self] _ in self?.isKeyboardVisible = false }
            .store(in: &cancellables)
    }
}
