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
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var showError = false
    @Published var currentUser: UserData?

    var isAuthenticated: Bool {
        return authService.isAuthenticated
    }
    
    // Profile completion check
    var isProfileCompleted: Bool {
        return currentUser?.isProfileCompleted ?? false
    }
    
    // Profile display properties
    var displayAge: String {
        if let age = currentUser?.age {
            return "\(age)"
        }
        return "Not set"
    }
    
    var displayGender: String {
        return currentUser?.gender ?? "Not set"
    }
    
    var displayFitnessLevel: String {
        return currentUser?.fitness_level ?? "Not set"
    }
    
    var displayHikingExperience: String {
        if let experience = currentUser?.hiking_experience_years {
            return String(format: "%.1f years", experience)
        }
        return "Not set"
    }
    
    init() {
        // Initialize with current user and observe changes
        self.currentUser = authService.currentUser
        
        // Observe auth service changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(userDataChanged),
            name: NSNotification.Name("UserDataChanged"),
            object: nil
        )
    }
    
    @objc private func userDataChanged() {
        DispatchQueue.main.async {
            self.currentUser = self.authService.currentUser
        }
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
    
    // Update profile method
    func updateProfile(
        age: Int,
        gender: String,
        fitnessLevel: String,
        hikingExperience: Double,
        completion: @escaping (Bool) -> Void
    ) {
        isLoading = true
        
        NetworkService.shared.updateProfile(
            age: age,
            gender: gender,
            fitnessLevel: fitnessLevel,
            hikingExperience: hikingExperience
        ) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                switch result {
                case .success(_):
                    // Refresh user data from backend
                    self?.refreshUserData { success in
                        completion(success)
                    }
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                    self?.showError = true
                    completion(false)
                }
            }
        }
    }
    
    // Refresh current user data
    func refreshUserData(completion: @escaping (Bool) -> Void) {
        authService.refreshCurrentUser { [weak self] success in
            DispatchQueue.main.async {
                if success {
                    self?.currentUser = self?.authService.currentUser
                }
                completion(success)
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
