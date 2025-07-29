import SwiftUI

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ProfileViewModel
    
    // Form state
    @State private var age: String = ""
    @State private var gender: String = "Male"
    @State private var fitnessLevel: String = "Beginner"
    @State private var hikingExperienceYears: String = ""
    
    // Validation state
    @State private var ageError: String = ""
    @State private var experienceError: String = ""
    @State private var showSuccess: Bool = false
    
    // Options
    private let genderOptions = ["Male", "Female", "Other"]
    private let fitnessLevelOptions = ["Beginner", "Intermediate", "Advanced"]
    
    // Computed properties
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
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Personal Information")) {
                    // Age Field
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Age")
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            TextField("Enter your age", text: $age)
                                .keyboardType(.numberPad)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 100)
                                .onChange(of: age) { _ in
                                    validateAge()
                                }
                        }
                        
                        if !ageError.isEmpty {
                            Text(ageError)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    
                    // Gender Picker
                    HStack {
                        Text("Gender")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Picker("Gender", selection: $gender) {
                            ForEach(genderOptions, id: \.self) { option in
                                Text(option).tag(option)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .frame(width: 120)
                    }
                }
                
                Section(header: Text("Fitness Information")) {
                    // Fitness Level Picker
                    HStack {
                        Text("Fitness Level")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Picker("Fitness Level", selection: $fitnessLevel) {
                            ForEach(fitnessLevelOptions, id: \.self) { option in
                                Text(option).tag(option)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .frame(width: 140)
                    }
                    
                    // Hiking Experience Field
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Hiking Experience (Years)")
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            TextField("0.0", text: $hikingExperienceYears)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 100)
                                .onChange(of: hikingExperienceYears) { _ in
                                    validateExperience()
                                }
                        }
                        
                        if !experienceError.isEmpty {
                            Text(experienceError)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveProfile()
                    }
                    .disabled(!isFormValid || viewModel.isLoading)
                }
            }
            .onAppear {
                loadCurrentValues()
            }
            .alert("Success!", isPresented: $showSuccess) {
                Button("OK") {
                    showSuccess = false
                    dismiss()
                }
            } message: {
                Text("Your profile has been updated successfully!")
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK") { viewModel.showError = false }
            } message: {
                Text(viewModel.errorMessage)
            }
        }
    }
    
    // MARK: - Methods
    private func loadCurrentValues() {
        if let currentUser = viewModel.currentUser {
            age = currentUser.age != nil ? String(currentUser.age!) : ""
            gender = currentUser.gender ?? "Male"
            fitnessLevel = currentUser.fitness_level ?? "Beginner"
            hikingExperienceYears = currentUser.hiking_experience_years != nil ? String(currentUser.hiking_experience_years!) : ""
        }
    }
    
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
    
    private func saveProfile() {
        guard let ageInt = Int(age),
              let experienceDouble = Double(hikingExperienceYears) else {
            return
        }
        
        viewModel.updateProfile(
            age: ageInt,
            gender: gender,
            fitnessLevel: fitnessLevel,
            hikingExperience: experienceDouble
        ) { success in
            if success {
                showSuccess = true
            }
        }
    }
}

// MARK: - Preview
struct EditProfileView_Previews: PreviewProvider {
    static var previews: some View {
        EditProfileView(viewModel: ProfileViewModel())
    }
} 