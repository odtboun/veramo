import SwiftUI
import Observation
import Supabase

struct SettingsView: View {
    @Bindable var authVM: AuthViewModel
    @State private var hasPartner = false
    @State private var showingPartnerConnection = false
    @State private var isRemovingPartner = false
    
    var body: some View {
        NavigationView {
            List {
                // Profile Section
                Section {
                    HStack {
                        AsyncImage(url: URL(string: "https://picsum.photos/60/60?random=1")) { image in
                            image
                                .resizable()
                                .aspectRatio(1, contentMode: .fit)
                                .clipShape(Circle())
                        } placeholder: {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .overlay {
                                    Image(systemName: "person.fill")
                                        .foregroundColor(.secondary)
                                }
                        }
                        .frame(width: 60, height: 60)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Your Profile")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            Text(hasPartner ? "Connected" : "Not Connected")
                                .font(.subheadline)
                                .foregroundColor(hasPartner ? .green : .secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
                
                // Partner Section
                Section("Partner") {
                    if hasPartner {
                        // Show partner info and remove option
                        HStack {
                            Image(systemName: "person.2.fill")
                                .foregroundColor(.green)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Partner Connected")
                                    .font(.headline)
                                
                                Text("You're sharing memories together")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                        .padding(.vertical, 4)
                        
                        Button(action: removePartner) {
                            HStack {
                                Image(systemName: "person.2.slash")
                                    .foregroundColor(.red)
                                
                                Text("Remove Partner")
                                    .font(.headline)
                                
                                Spacer()
                                
                                if isRemovingPartner {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                }
                            }
                        }
                        .foregroundColor(.red)
                        .disabled(isRemovingPartner)
                    } else {
                        // Show connect option
                        Button(action: { showingPartnerConnection = true }) {
                            HStack {
                                Image(systemName: "person.2.fill")
                                    .foregroundColor(.blue)
                                
                                Text("Connect with Partner")
                                    .font(.headline)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .foregroundColor(.primary)
                    }
                }
                
                // Subscription Section
                Section("Subscription") {
                    HStack {
                        Image(systemName: "crown.fill")
                            .foregroundColor(.yellow)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Premium Features")
                                .font(.headline)
                            
                            Text("Unlimited AI generation, advanced editing")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button("Upgrade") {
                            // Handle subscription
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.blue.opacity(0.1))
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                // App Settings
                Section("App") {
                    SettingsRow(icon: "bell.fill", title: "Notifications", action: {})
                    SettingsRow(icon: "lock.fill", title: "Privacy", action: {})
                    SettingsRow(icon: "questionmark.circle.fill", title: "Help & Support", action: {})
                    SettingsRow(icon: "info.circle.fill", title: "About", action: {})
                }
                
                // Account Section
                Section("Account") {
                    Button("Sign Out") {
                        Task { await authVM.signOut() }
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                checkPartnerStatus()
            }
        }
        .sheet(isPresented: $showingPartnerConnection) {
            PartnerConnectionView()
                .onDisappear {
                    checkPartnerStatus()
                }
        }
    }
    
    private func checkPartnerStatus() {
        Task {
            let couple = await SupabaseService.shared.fetchCouple()
            await MainActor.run {
                hasPartner = (couple != nil)
            }
        }
    }
    
    private func removePartner() {
        isRemovingPartner = true
        Task {
            do {
                try await SupabaseService.shared.removePartner()
                await MainActor.run {
                    hasPartner = false
                    isRemovingPartner = false
                }
            } catch {
                await MainActor.run {
                    isRemovingPartner = false
                    print("Failed to remove partner: \(error)")
                }
            }
        }
    }
}

struct SettingsRow: View {
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
                    .font(.headline)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .foregroundColor(.primary)
    }
}

#Preview {
    SettingsView(authVM: AuthViewModel())
}