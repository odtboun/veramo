import SwiftUI

struct SettingsView: View {
    @State private var isPaired = false
    @State private var partnerName = "Not Connected"
    @State private var showingPairingSheet = false
    
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
                            
                            Text(partnerName)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
                
                // Pairing Section
                Section("Partner") {
                    if isPaired {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Connected")
                                    .font(.headline)
                                
                                Text("Partner: \(partnerName)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Button("Disconnect") {
                                disconnectPartner()
                            }
                            .font(.caption)
                            .foregroundColor(.red)
                        }
                        .padding(.vertical, 4)
                    } else {
                        Button(action: {
                            showingPairingSheet = true
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
            .sheet(isPresented: $showingPairingSheet) {
                PairingView(isPresented: $showingPairingSheet) { partner in
                    isPaired = true
                    partnerName = partner
                }
            }
        }
    }
    
    private func disconnectPartner() {
        isPaired = false
        partnerName = "Not Connected"
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

struct PairingView: View {
    @Binding var isPresented: Bool
    let onPair: (String) -> Void
    
    @State private var pairingCode = "ABC123"
    @State private var enteredCode = ""
    @State private var isGeneratingCode = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                VStack(spacing: 16) {
                    Text("Connect with Your Partner")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    Text("Share your code or enter your partner's code to connect")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top)
                
                VStack(spacing: 24) {
                    // Generate Code Section
                    VStack(spacing: 16) {
                        Text("Your Code")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text(pairingCode)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                            .padding()
                            .background {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.ultraThinMaterial)
                            }
                        
                        Button("Generate New Code") {
                            generateNewCode()
                        }
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    }
                    
                    Divider()
                    
                    // Enter Code Section
                    VStack(spacing: 16) {
                        Text("Enter Partner's Code")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        TextField("Enter code", text: $enteredCode)
                            .textFieldStyle(.roundedBorder)
                            .font(.title2)
                            .multilineTextAlignment(.center)
                        
                        Button("Connect") {
                            connectWithCode()
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.blue)
                        }
                        .disabled(enteredCode.isEmpty)
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
    }
    
    private func generateNewCode() {
        isGeneratingCode = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            pairingCode = String((100000...999999).randomElement() ?? 123456)
            isGeneratingCode = false
        }
    }
    
    private func connectWithCode() {
        // Simulate connection
        onPair("Partner Name")
        isPresented = false
    }
}

#Preview {
    SettingsView()
}
