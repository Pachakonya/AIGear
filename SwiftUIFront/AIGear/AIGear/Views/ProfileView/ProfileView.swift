import SwiftUI

struct ProfileView: View {
    @StateObject private var viewModel = ProfileViewModel()
    @State private var showingSignOutAlert = false
    @State private var showingDeleteAlert = false
    @State private var isDeleting = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Profile Header
                VStack(spacing: 16) {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .frame(width: 80, height: 80)
                        .foregroundColor(.blue)
                    
                    VStack(spacing: 4) {
                        Text(viewModel.currentUser?.username ?? "User")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text(viewModel.currentUser?.email ?? "")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top)
                
                // Profile Options
                VStack(spacing: 0) {
                    ProfileOptionRow(icon: "gear", title: "Settings", action: {})
                    ProfileOptionRow(icon: "bell", title: "Notifications", action: {})
                   
                }
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
                
                // About Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("About")
                        .font(.headline)
                        .padding(.leading)
                    VStack(spacing: 0) {
                        NavigationLink(destination: SupportView()) {
                            ProfileOptionRow(icon: "questionmark.circle", title: "Support", action: {})
                        }
                        NavigationLink(destination: PrivacyPolicyView()) {
                            ProfileOptionRow(icon: "doc.text", title: "Privacy Policy", action: {})
                        }
                        NavigationLink(destination: TermsOfServiceView()) {
                            ProfileOptionRow(icon: "doc.text", title: "Terms of Service", action: {})
                        }
                    }
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                
                Spacer()
                
                // Sign Out Button
                Button(action: {
                    showingSignOutAlert = true
                }) {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                        Text("Sign Out")
                    }
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                .alert("Sign Out", isPresented: $showingSignOutAlert) {
                    Button("Cancel", role: .cancel) { }
                    Button("Sign Out", role: .destructive) {
                        viewModel.signOut()
                    }
                } message: {
                    Text("Are you sure you want to sign out?")
                }
                
                // Delete Account Button
                Button(action: {
                    showingDeleteAlert = true
                }) {
                    HStack {
                        Image(systemName: "trash")
                        Text("Delete Account")
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                .alert("Delete Account", isPresented: $showingDeleteAlert) {
                    Button("Cancel", role: .cancel) { }
                    Button("Delete", role: .destructive) {
                        isDeleting = true
                        viewModel.deleteAccount { result in
                            isDeleting = false
                            switch result {
                            case .success:
                                // Optionally show a success message or just rely on signOut
                                break
                            case .failure(let error):
                                // Optionally show an error alert
                                print("Delete failed: \(error.localizedDescription)")
                            }
                        }
                    }
                } message: {
                    Text("Are you sure you want to permanently delete your account? This action cannot be undone.")
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

struct ProfileOptionRow: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                    .frame(width: 24)
                
                Text(title)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .padding()
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    ProfileView()
} 