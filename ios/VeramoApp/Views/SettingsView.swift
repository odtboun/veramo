import SwiftUI
import Observation
import Supabase
import Adapty

struct SettingsView: View {
    @Bindable var authVM: AuthViewModel
    @State private var hasPartner = false
    @State private var showingPartnerConnection = false
    @State private var isRemovingPartner = false
    @State private var isCheckingSubscription = false
    @State private var isSubscribed = false
    @State private var subscriptionError: String?
    
    var body: some View {
        NavigationView {
            List {
                // Top padding since profile section is removed (match grouped background)
                Color(UIColor.systemGroupedBackground)
                    .frame(height: 12)
                    .listRowBackground(Color(UIColor.systemGroupedBackground))
                
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
                        Image(systemName: "star.circle.fill")
                            .foregroundColor(.yellow)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Status")
                                .font(.headline)
                            if isCheckingSubscription {
                                HStack(spacing: 8) {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Checking...")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            } else if let subscriptionError = subscriptionError {
                                Text(subscriptionError)
                                    .font(.subheadline)
                                    .foregroundColor(.red)
                            } else {
                                Text(isSubscribed ? "Subscribed" : "Not Subscribed")
                                    .font(.subheadline)
                                    .foregroundColor(isSubscribed ? .green : .secondary)
                            }
                        }
                        Spacer()
                        Button(action: checkSubscriptionStatus) {
                            Image(systemName: "arrow.clockwise")
                        }
                        .disabled(isCheckingSubscription)
                    }
                    .padding(.vertical, 4)
                }
                
                
                // App Settings
                Section("App") {
                    SettingsRow(icon: "bell.fill", title: "Notifications", action: {})
                    SettingsRow(icon: "lock.fill", title: "Privacy", action: {})
                    SettingsRow(icon: "questionmark.circle.fill", title: "Help & Support", action: {})
                    SettingsRow(icon: "info.circle.fill", title: "About", action: {})
                    // Temporary: Reset onboarding for testing (local only)
                    SettingsRow(icon: "arrow.counterclockwise", title: "Reset Onboarding (Temp)") {
                        // Clear local flag; remote field doesn't exist yet
                        UserDefaults.standard.set(false, forKey: "onboarding_completed")
                    }
                }
                
                // Account Section
                Section("Account") {
                    Button("Sign Out") {
                        Task { await authVM.signOut() }
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationBarHidden(true)
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                checkPartnerStatus()
                checkSubscriptionStatus()
            }
        }
        .sheet(isPresented: $showingPartnerConnection) {
            PartnerConnectionView()
                .onDisappear {
                    checkPartnerStatus()
                    checkSubscriptionStatus()
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

    private func checkSubscriptionStatus() {
        isCheckingSubscription = true
        subscriptionError = nil
        Task {
            do {
                // If part of an active couple, check couple-level subscription
                if let couple = await SupabaseService.shared.fetchCouple(), couple.is_active {
                    let coupleSubscribed = try await SupabaseService.shared.checkCoupleSubscriptionStatus()
                    await MainActor.run {
                        self.isSubscribed = coupleSubscribed
                        self.isCheckingSubscription = false
                    }
                } else {
                    // Fallback: check current user's Adapty profile directly
                    let profile = try await Adapty.getProfile()
                    let active = profile.accessLevels["premium"]?.isActive ?? false
                    await MainActor.run {
                        self.isSubscribed = active
                        self.isCheckingSubscription = false
                    }
                }
            } catch {
                await MainActor.run {
                    self.subscriptionError = "Failed to check subscription"
                    self.isSubscribed = false
                    self.isCheckingSubscription = false
                }
                print("❌ Subscription check failed: \(error)")
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