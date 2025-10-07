import SwiftUI
import Adapty

enum PartnerStatus: String, CaseIterable {
    case yes = "Yes"
    case no = "No"
}

struct OnboardingFlow: View {
    let partnerAlreadyOnboarded: Bool
    let onFinish: () -> Void
    @State private var step: Int = 1
    @State private var partnerName: String = ""
    @State private var relationshipStart: Date = Date()
    @State private var showingShareSheet: Bool = false
    @State private var shareImage: UIImage? = nil
    @State private var animateBlob: Bool = false // unused after redesign; kept to avoid accidental rebuild churn
    @State private var partnerSelection: PartnerStatus? = nil // NEW: Track partner selection
    @State private var inviteCode: String = "" // NEW: Track invite code input
    @State private var isConnecting: Bool = false // NEW: Track connection state
    @State private var connectionError: String? = nil // NEW: Track connection errors
    @State private var userName: String = "love" // NEW: Default user name for shareable image
    
    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 20)
                .padding(.top, 16)

            // Full-screen step content
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.horizontal, 20)
                .padding(.top, 12)

            controls
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
        }
        .background(Color(.systemBackground))
        .sheet(isPresented: $showingShareSheet) {
            if let img = shareImage {
                ActivityView(activityItems: [img])
            }
        }
    }

    // Using system background for proper dark mode support
    private var backgroundLayer: some View { Color(.systemBackground).ignoresSafeArea() }

    private var header: some View {
        VStack(spacing: 8) {
            Text("Step \(step) of 6")
                .font(.footnote)
                .foregroundColor(.secondary)
            pageDots
        }
    }

    private var content: some View {
        // Full-screen sections, no cards
        Group {
            switch step {
            case 1: step1
            case 2: step2
            case 3: step3
            case 4: step4
            case 5: step5
            default: step6
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.9), value: step)
    }

    private var controls: some View {
        HStack(spacing: 12) {
            if step > 1 {
                Button(action: { withAnimation { step -= 1 } }) {
                    HStack { Image(systemName: "chevron.left"); Text("Back") }
                        .font(.headline.weight(.semibold))
                        .padding(.vertical, 12)
                        .padding(.horizontal, 20)
                }
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(.ultraThinMaterial)
                        .overlay {
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(.primary.opacity(0.2), lineWidth: 1)
                        }
                )
                .foregroundColor(.primary)
            }
            Spacer(minLength: 0)
            Button(action: {
                if step == 1 {
                    // Handle step 1 logic
                    if partnerSelection == .yes && !inviteCode.isEmpty {
                        // Connect with partner using invite code
                        Task {
                            await connectWithPartner()
                        }
                    } else if partnerSelection == .no {
                        // Proceed to next step if partner is not on Veramo
                        withAnimation { step += 1 }
                    }
                } else if step < 6 {
                    withAnimation { step += 1 }
                } else {
                    // Temporary: finish onboarding and hand off to paywall elsewhere
                    // We will present Adapty placement paywall from the root later
                    onFinish()
                }
            }) {
                HStack(spacing: 8) {
                    if step == 1 && partnerSelection == .yes && isConnecting {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.8)
                        Text("Connecting...")
                            .font(.headline.weight(.semibold))
                    } else {
                        Text(step < 6 ? "Continue" : "Get started")
                            .font(.headline.weight(.semibold))
                        Image(systemName: step < 6 ? "arrow.right" : "creditcard")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(colors: [.pink, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: .pink.opacity(0.3), radius: 8, x: 0, y: 6)
            }
            .buttonStyle(.plain)
            .disabled(step == 1 && (partnerSelection == nil || (partnerSelection == .yes && inviteCode.isEmpty))) // Disable if no selection or if partner is yes but no invite code
            .opacity(step == 1 && (partnerSelection == nil || (partnerSelection == .yes && inviteCode.isEmpty)) ? 0.5 : 1.0) // Visual feedback for disabled state
        }
    }

    // Removed card wrapper to keep steps full-screen on white background
    private func card(_ inner: some View) -> some View { inner }
    
    // MARK: - Partner Connection
    
    private func connectWithPartner() async {
        guard !inviteCode.isEmpty else { return }
        
        await MainActor.run {
            isConnecting = true
            connectionError = nil
        }
        
        do {
            try await SupabaseService.shared.joinWithCode(inviteCode)
            await MainActor.run {
                isConnecting = false
                // Success - proceed to next step
                withAnimation { step += 1 }
            }
        } catch {
            await MainActor.run {
                isConnecting = false
                connectionError = "Failed to connect: \(error.localizedDescription)"
            }
        }
    }

    // (Paywall presentation will be wired from root after this screen if needed.)

    private var pageDots: some View {
        HStack(spacing: 6) {
            ForEach(1...6, id: \.self) { i in
                Circle()
                    .fill(i == step ? Color.primary : Color.secondary.opacity(0.3))
                    .frame(width: i == step ? 8 : 6, height: i == step ? 8 : 6)
                    .animation(.easeInOut, value: step)
            }
        }
    }

    // MARK: - Steps
    private var step1: some View {
        VStack(spacing: 18) {
            Text("The Easiest Way to Build Your Shared Story.")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
            Text("Turn everyday moments into a beautiful visual keepsake you both build over time.")
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            // Media placeholder (illustration)
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.secondary.opacity(0.08))
                .frame(height: 240)
                .overlay { Text("Illustration Placeholder") }
            
            // Partner question
            VStack(spacing: 12) {
                Text("Is your partner already on Veramo?")
                    .font(.title2.weight(.semibold))
                    .multilineTextAlignment(.center)
                
                HStack(spacing: 12) {
                    ForEach(PartnerStatus.allCases, id: \.self) { status in
                        Button(action: {
                            partnerSelection = status
                            // Clear invite code when switching selections
                            if status == .no {
                                inviteCode = ""
                                connectionError = nil
                            }
                        }) {
                            Text(status.rawValue)
                                .font(.headline.weight(.semibold))
                                .foregroundColor(partnerSelection == status ? .white : .primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(partnerSelection == status ? Color.pink : Color.secondary.opacity(0.1))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(partnerSelection == status ? Color.pink : Color.clear, lineWidth: 2)
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                // Show invite code input only if partner is already on Veramo
                if partnerSelection == .yes {
                    VStack(spacing: 8) {
                        Text("Your partner's invite code:")
                            .font(.headline.weight(.semibold))
                            .multilineTextAlignment(.center)
                            .padding(.top, 8)
                        
                        TextField("Enter invite code", text: $inviteCode)
                            .textFieldStyle(.roundedBorder)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .onChange(of: inviteCode) { _, newValue in
                                // Clear error when user starts typing
                                connectionError = nil
                            }
                        
                        if let error = connectionError {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                        }
                        
                        if isConnecting {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Connecting...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.top, 8)
                }
            }
            .padding(.top, 8)
        }
    }

    private var step2: some View {
        VStack(spacing: 18) {
            Text("Personalize Your Experience")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
            // Multiple choice: Partner already on Veramo?
            VStack(alignment: .leading, spacing: 12) {
                Text("Is your partner already on Veramo?")
                    .font(.headline)
                HStack(spacing: 8) {
                    Button("Yes") { /* store selection later */ }
                        .buttonStyle(.bordered)
                    Button("No") { /* store selection later */ }
                        .buttonStyle(.bordered)
                }
            }
            VStack(alignment: .leading, spacing: 12) {
                TextField("Partner's name", text: $partnerName)
                    .textFieldStyle(.roundedBorder)
                DatePicker("When did your story begin?", selection: $relationshipStart, displayedComponents: .date)
            }
        }
    }

    private var step3: some View {
        VStack(spacing: 18) {
            Text("A Glimpse of the Magic ✨")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
            Text("See how memories turn into visuals in seconds.")
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            // Media placeholder (animation)
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.secondary.opacity(0.08))
                .frame(height: 260)
                .overlay { Text("Animation Placeholder") }
        }
    }

    private var step4: some View {
        VStack(spacing: 18) {
            Text("Your Shared Timeline")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
            Text("Memories land on your shared calendar. Schedule gifts in advance.")
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            // Media placeholder (calendar illustration)
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.secondary.opacity(0.08))
                .frame(height: 240)
                .overlay { Text("Calendar Illustration Placeholder") }
        }
    }

    private var step5: some View {
        VStack(spacing: 18) {
            Text("Keep It Visible with a Widget")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
            Text("See your latest memory on your Home Screen.")
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            // Media placeholder (widget mock)
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.secondary.opacity(0.08))
                .frame(height: 240)
                .overlay { Text("Widget Mock Placeholder") }
        }
    }

    private var step6: some View {
        VStack(spacing: 18) {
            Text("Invite Your Partner with a Promise")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
            Text("Share a letter-like image: 'I'm committing to creating beautiful memories for a year & beyond.'")
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                    Button("Generate & Share") {
                        // Custom square shareable image
                        let renderer = ImageRenderer(content:
                            ZStack {
                                // Solid background color (using a warm gradient for visual appeal)
                                LinearGradient(
                                    colors: [Color.pink.opacity(0.1), Color.purple.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                
                                VStack(alignment: .leading, spacing: 0) {
                                    Spacer()
                                    
                                    // Main commitment text
                                    Text("I commit to fill our calendar with beautiful memories. Join me on Veramo <3")
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)
                                        .multilineTextAlignment(.leading)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 24)
                                        .padding(.bottom, 24)
                                    
                                    Spacer()
                                    
                                    // User name at bottom right
                                    HStack {
                                        Spacer()
                                        Text(userName)
                                            .font(.headline)
                                            .fontWeight(.bold)
                                            .foregroundColor(.pink)
                                            .padding(.trailing, 24)
                                            .padding(.bottom, 24)
                                    }
                                }
                            }
                            .frame(width: 600, height: 600) // Square image
                        )
                        if let ui = renderer.uiImage { shareImage = ui; showingShareSheet = true }
                    }
                    .font(.headline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(colors: [.pink, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .pink.opacity(0.3), radius: 8, x: 0, y: 6)
            .buttonStyle(.plain)
        }
    }
}

// UIKit wrapper for share sheet
struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: activityItems, applicationActivities: nil) }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}


