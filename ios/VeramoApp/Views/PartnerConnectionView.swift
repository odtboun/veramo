import SwiftUI
import Supabase

struct PartnerConnectionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showingGenerateCode = false
    @State private var showingEnterCode = false
    @State private var generatedCode = ""
    @State private var isGenerating = false
    @State private var isJoining = false
    @State private var joinCode = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "person.2.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Connect with Your Partner")
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    Text("Choose how you'd like to connect")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)
                
                // Action Buttons
                VStack(spacing: 16) {
                    // Generate Code Button
                    Button(action: { showingGenerateCode = true }) {
                        HStack {
                            Image(systemName: "qrcode")
                                .font(.title2)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Generate Code")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                
                                Text("Create a code for your partner to enter")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.ultraThinMaterial)
                        }
                    }
                    .buttonStyle(.plain)
                    
                    // Enter Code Button
                    Button(action: { showingEnterCode = true }) {
                        HStack {
                            Image(systemName: "keyboard")
                                .font(.title2)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Enter Partner Code")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                
                                Text("Join with a code from your partner")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.ultraThinMaterial)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal)
                
                // Explanation
                VStack(spacing: 12) {
                    Text("How it works")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top, spacing: 12) {
                            Text("1")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                                .frame(width: 24, height: 24)
                                .background(Circle().fill(.blue.opacity(0.1)))
                            
                            Text("One partner generates a 6-character code")
                                .font(.subheadline)
                        }
                        
                        HStack(alignment: .top, spacing: 12) {
                            Text("2")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                                .frame(width: 24, height: 24)
                                .background(Circle().fill(.blue.opacity(0.1)))
                            
                            Text("The other partner enters the code in their app")
                                .font(.subheadline)
                        }
                        
                        HStack(alignment: .top, spacing: 12) {
                            Text("3")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                                .frame(width: 24, height: 24)
                                .background(Circle().fill(.blue.opacity(0.1)))
                            
                            Text("You're connected! Start sharing memories together")
                                .font(.subheadline)
                        }
                    }
                }
                .padding()
                .background {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle("Partner Connection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingGenerateCode) {
            GenerateCodeView(
                isGenerating: $isGenerating,
                generatedCode: $generatedCode,
                onDismiss: { showingGenerateCode = false }
            )
        }
        .sheet(isPresented: $showingEnterCode) {
            EnterCodeView(
                isJoining: $isJoining,
                joinCode: $joinCode,
                onSuccess: {
                    showingEnterCode = false
                    dismiss()
                },
                onDismiss: { showingEnterCode = false }
            )
        }
        .alert("Connection Result", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
}

struct GenerateCodeView: View {
    @Binding var isGenerating: Bool
    @Binding var generatedCode: String
    let onDismiss: () -> Void
    @State private var showingShare = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                if isGenerating {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                        
                        Text("Generating your code...")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                } else if !generatedCode.isEmpty {
                    VStack(spacing: 24) {
                        Text("Your Partner Code")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        // Code Display
                        Text(generatedCode)
                            .font(.system(size: 48, weight: .bold, design: .monospaced))
                            .foregroundColor(.blue)
                            .padding()
                            .background {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.blue.opacity(0.1))
                            }
                        
                        Text("Share this code with your partner")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button(action: { showingShare = true }) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("Share Code")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.blue)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "qrcode")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        Text("Ready to generate your code?")
                            .font(.headline)
                            .multilineTextAlignment(.center)
                        
                        Button("Generate Code") {
                            Task {
                                isGenerating = true
                                do {
                                    generatedCode = try await SupabaseService.shared.generatePairingCode()
                                } catch {
                                    print("Failed to generate code: \(error)")
                                }
                                isGenerating = false
                            }
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.blue)
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Generate Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onDismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingShare) {
            ShareSheet(items: [generatedCode])
        }
    }
}

struct EnterCodeView: View {
    @Binding var isJoining: Bool
    @Binding var joinCode: String
    let onSuccess: () -> Void
    let onDismiss: () -> Void
    @State private var code = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                VStack(spacing: 16) {
                    Image(systemName: "keyboard")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Enter Partner Code")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Ask your partner for their 6-character code")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                VStack(spacing: 16) {
                    TextField("Enter code", text: $code)
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .multilineTextAlignment(.center)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.allCharacters)
                        .disableAutocorrection(true)
                        .onChange(of: code) { _, newValue in
                            code = String(newValue.prefix(6).uppercased())
                        }
                    
                    Button(action: joinWithCode) {
                        HStack {
                            if isJoining {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .foregroundColor(.white)
                            }
                            
                            Text(isJoining ? "Connecting..." : "Connect")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(code.count == 6 ? .blue : .gray)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(code.count != 6 || isJoining)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Enter Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onDismiss()
                    }
                }
            }
        }
        .alert("Connection Result", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func joinWithCode() {
        guard code.count == 6 else { return }
        
        isJoining = true
        Task {
            do {
                try await SupabaseService.shared.joinWithCode(code)
                await MainActor.run {
                    onSuccess()
                }
            } catch {
                await MainActor.run {
                    alertMessage = "Failed to connect: \(error.localizedDescription)"
                    showingAlert = true
                    isJoining = false
                }
            }
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    PartnerConnectionView()
}
