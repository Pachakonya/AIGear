import SwiftUI

struct ProfileSetupView: View {
    // MARK: - State Properties
    @State private var age: String = ""
    @State private var gender: String = "Male"
    @State private var fitnessLevel: String = "Beginner"
    @State private var hikingExperienceYears: String = ""
    
    // MARK: - Validation State
    @State private var ageError: String = ""
    @State private var experienceError: String = ""
    
    // MARK: - UI State
    @State private var isLoading: Bool = false
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    @State private var showSuccess: Bool = false
    
    // MARK: - Configuration
    let isEditingMode: Bool
    let onComplete: () -> Void
    let onCancel: (() -> Void)?
    
    // MARK: - Initializers
    init(isEditingMode: Bool = false, onComplete: @escaping () -> Void, onCancel: (() -> Void)? = nil) {
        self.isEditingMode = isEditingMode
        self.onComplete = onComplete
        self.onCancel = onCancel
    }
    
    // MARK: - Gender Options
    private let genderOptions = ["Male", "Female", "Other"]
    
    // MARK: - Fitness Level Options
    private let fitnessLevelOptions = ["Beginner", "Intermediate", "Advanced"]
    
    // MARK: - Computed Properties
    private var isFormValid: Bool {
        return isAgeValid && isExperienceValid && !age.isEmpty && !hikingExperienceYears.isEmpty
    }
    
    private var isAgeValid: Bool {
        guard let ageInt = Int(age), ageInt > 4 else { return false }
        return true
    }
    
    private var isExperienceValid: Bool {
        guard let experienceDouble = Double(hikingExperienceYears), experienceDouble >= 0 else { return false }
        return true
    }
    
    private var titleText: String {
        return isEditingMode ? "Edit Your Profile" : "Complete Your Profile"
    }
    
    private var subtitleText: String {
        return isEditingMode ? "Update your information to keep recommendations accurate" : "Help us personalize your hiking experience"
    }
    
    private var buttonText: String {
        return isEditingMode ? "Save" : "Continue"
    }
    
    private var loadingText: String {
        return isEditingMode ? "Saving..." : "Saving..."
    }
    
    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ZStack {
                    AuthBackgroundView()
                    
                    ScrollView {
                        VStack(spacing: 28) {
                            Spacer(minLength: geo.size.height * 0.08)
                            
                            // Title
                            Text(titleText)
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .shadow(color: .black.opacity(0.7), radius: 4, x: 0, y: 2)
                                .padding(.horizontal, 16)
                            
                            Text(subtitleText)
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.85))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 16)
                            
                            // Profile setup card with blur
                            VStack(spacing: 24) {
                                // Personal Information Section
                                VStack(alignment: .leading, spacing: 16) {
                                    Text("Personal Information")
                                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                                        .foregroundColor(.white)
                                    
                                    // Age Field
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Text("Age")
                                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                                .foregroundColor(.white.opacity(0.9))
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                            
                                            TextField("Enter your age", text: $age)
                                                .keyboardType(.numberPad)
                                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 10)
                                                .background(.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                                .frame(width: 140)
                                                .onChange(of: age) { _ in
                                                    validateAge()
                                                }
                                        }
                                        
                                        if !ageError.isEmpty {
                                            Text(ageError)
                                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                                .foregroundColor(.red.opacity(0.9))
                                                .padding(.leading, 4)
                                        }
                                    }
                                    
                                    // Gender Picker
                                    HStack {
                                        Text("Gender")
                                            .font(.system(size: 16, weight: .medium, design: .rounded))
                                            .foregroundColor(.white.opacity(0.9))
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        
                                        Menu {
                                            ForEach(genderOptions, id: \.self) { option in
                                                Button(option) {
                                                    gender = option
                                                }
                                            }
                                        } label: {
                                            HStack {
                                                Text(gender)
                                                    .font(.system(size: 16, weight: .medium, design: .rounded))
                                                    .foregroundColor(.black)
                                                Spacer()
                                                Image(systemName: "chevron.down")
                                                    .font(.system(size: 12, weight: .semibold))
                                                    .foregroundColor(.black.opacity(0.6))
                                            }
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 10)
                                            .background(.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                            .frame(width: 140)
                                        }
                                    }
                                }
                                
                                // Separator
                                Rectangle()
                                    .frame(height: 1)
                                    .foregroundColor(.white.opacity(0.25))
                                    .padding(.horizontal, 8)
                                
                                // Fitness Information Section
                                VStack(alignment: .leading, spacing: 16) {
                                    Text("Fitness Information")
                                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                                        .foregroundColor(.white)
                                    
                                    // Fitness Level Picker
                                    HStack {
                                        Text("Fitness Level")
                                            .font(.system(size: 16, weight: .medium, design: .rounded))
                                            .foregroundColor(.white.opacity(0.9))
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        
                                        Menu {
                                            ForEach(fitnessLevelOptions, id: \.self) { option in
                                                Button(option) {
                                                    fitnessLevel = option
                                                }
                                            }
                                        } label: {
                                            HStack {
                                                Text(fitnessLevel)
                                                    .font(.system(size: 16, weight: .medium, design: .rounded))
                                                    .foregroundColor(.black)
                                                Spacer()
                                                Image(systemName: "chevron.down")
                                                    .font(.system(size: 12, weight: .semibold))
                                                    .foregroundColor(.black.opacity(0.6))
                                            }
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 10)
                                            .background(.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                            .frame(width: 140)
                                        }
                                    }
                                    
                                    // Hiking Experience Field
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Text("Hiking Experience (Years)")
                                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                                .foregroundColor(.white.opacity(0.9))
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                            
                                            TextField("0.0", text: $hikingExperienceYears)
                                                .keyboardType(.decimalPad)
                                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 10)
                                                .background(.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                                .frame(width: 100)
                                                .onChange(of: hikingExperienceYears) { _ in
                                                    validateExperience()
                                                }
                                        }
                                        
                                        if !experienceError.isEmpty {
                                            Text(experienceError)
                                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                                .foregroundColor(.red.opacity(0.9))
                                                .padding(.leading, 4)
                                        }
                                    }
                                }
                                
                                // Save/Continue Button
                                Button(action: {
                                    saveProfile()
                                }) {
                                    HStack {
                                        if isLoading {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: isFormValid ? .black : .white.opacity(0.7)))
                                                .scaleEffect(0.8)
                                        }
                                        
                                        Spacer()
                                        
                                        Text(isLoading ? loadingText : buttonText)
                                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                                            .foregroundColor(isFormValid ? .black : .white.opacity(0.7))
                                        
                                        Spacer()
                                    }
                                    .frame(height: 52)
                                    .background(isFormValid ? .white : .white.opacity(0.3), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                    .shadow(color: .black.opacity(isFormValid ? 0.12 : 0.05), radius: 8, x: 0, y: 4)
                                }
                                .disabled(!isFormValid || isLoading)
                                .padding(.top, 8)
                            }
                            .padding(.vertical, 28)
                            .padding(.horizontal, 20)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
                            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                            .shadow(color: .black.opacity(0.18), radius: 16, x: 0, y: 8)
                            .padding(.horizontal, 16)
                            
                            Spacer(minLength: 60)
                        }
                        .frame(minHeight: geo.size.height)
                    }
                }
            }
            .navigationBarHidden(!isEditingMode)
            .toolbar {
                if isEditingMode {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            onCancel?()
                        }
                        .foregroundColor(.white)
                        .font(.body)
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { showError = false }
            } message: {
                Text(errorMessage)
            }
            .alert("Success!", isPresented: $showSuccess) {
                Button(isEditingMode ? "Done" : "Continue") { 
                    showSuccess = false
                    onComplete()
                }
            } message: {
                Text(isEditingMode ? "Your profile has been updated successfully!" : "Your profile has been saved successfully!")
            }
            .onAppear {
                if isEditingMode {
                    loadCurrentValues()
                }
            }
        }
        .tint(.black)
    }
    
    // MARK: - Methods
    private func loadCurrentValues() {
        if let currentUser = AuthService.shared.currentUser {
            age = currentUser.age != nil ? String(currentUser.age!) : ""
            gender = currentUser.gender ?? "Male"
            fitnessLevel = currentUser.fitness_level ?? "Beginner"
            hikingExperienceYears = currentUser.hiking_experience_years != nil ? String(currentUser.hiking_experience_years!) : ""
        }
    }
    
    // MARK: - Validation Methods
    private func validateAge() {
        if age.isEmpty {
            ageError = ""
        } else if let ageInt = Int(age) {
            if ageInt <= 4 {
                ageError = "Age must be greater than 4"
            } else {
                ageError = ""
            }
        } else {
            ageError = "Please enter a valid number"
        }
    }
    
    private func validateExperience() {
        if hikingExperienceYears.isEmpty {
            experienceError = ""
        } else if let experienceDouble = Double(hikingExperienceYears) {
            if experienceDouble < 0 {
                experienceError = "Experience cannot be negative"
            } else {
                experienceError = ""
            }
        } else {
            experienceError = "Please enter a valid number"
        }
    }
    
    // MARK: - API Methods
    private func saveProfile() {
        guard let ageInt = Int(age),
              let experienceDouble = Double(hikingExperienceYears) else {
            return
        }
        
        isLoading = true
        
        NetworkService.shared.updateProfile(
            age: ageInt,
            gender: gender,
            fitnessLevel: fitnessLevel,
            hikingExperience: experienceDouble
        ) { result in
            DispatchQueue.main.async {
                isLoading = false
                
                switch result {
                case .success(_):
                    showSuccess = true
                case .failure(let error):
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

// MARK: - Preview Provider
struct ProfileSetupView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Initial setup mode
            ProfileSetupView {
                print("Profile setup completed")
            }
            
            // Editing mode
            ProfileSetupView(isEditingMode: true, onComplete: {
                print("Profile updated")
            }, onCancel: {
                print("Cancelled")
            })
        }
    }
} 
