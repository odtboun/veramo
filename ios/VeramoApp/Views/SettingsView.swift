import SwiftUI

struct SettingsView: View {
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
                            
                            Text("Not Connected")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
                
                // Pairing Section
                Section("Partner") {
                    Button(action: {
                        // Connect with partner
                    }) {
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
                        // Handle sign out
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
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
    SettingsView()
}
