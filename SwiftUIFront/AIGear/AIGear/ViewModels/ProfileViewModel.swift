//
//  ProfileViewModel.swift
//  AIGear
//
//  Created by Dastan Sugirbay on 19.06.2025.
//

import Foundation
import SwiftUI

class ProfileViewModel: ObservableObject {
    @StateObject private var authService = AuthService.shared
    
    var currentUser: UserData? {
        return authService.currentUser
    }
    
    var isAuthenticated: Bool {
        return authService.isAuthenticated
    }
    
    func signOut() {
        authService.signOut()
    }
}
