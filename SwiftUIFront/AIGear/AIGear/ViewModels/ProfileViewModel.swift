//
//  ProfileViewModel.swift
//  AIGear
//
//  Created by Dastan Sugirbay on 19.06.2025.
//

import Foundation
import SwiftUI

class ProfileViewModel: ObservableObject {
    private let authService = AuthService.shared

    var currentUser: UserData? {
        return authService.currentUser
    }

    var isAuthenticated: Bool {
        return authService.isAuthenticated
    }

    func signOut() {
        authService.signOut()
    }

    func deleteAccount(completion: @escaping (Result<Void, Error>) -> Void) {
        NetworkService.shared.deleteAccount { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self.signOut() // Log out after deletion
                    completion(.success(()))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }
}
