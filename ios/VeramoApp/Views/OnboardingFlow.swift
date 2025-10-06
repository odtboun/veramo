import SwiftUI
import Adapty

struct OnboardingFlow: View {
    let partnerAlreadyOnboarded: Bool
    let onFinish: () -> Void
    @State private var step: Int = 1
    @State private var partnerName: String = ""
    @State private var relationshipStart: Date = Date()
    @State private var showingShareSheet: Bool = false
    @State private var shareImage: UIImage? = nil
    @State private var animateBlob: Bool = false // unused after redesign; kept to avoid accidental rebuild churn
    
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
        .background(Color.white)
        .sheet(isPresented: $showingShareSheet) {
            if let img = shareImage {
                ActivityView(activityItems: [img])
            }
        }
    }

    // Removed colorful background; using solid white background as requested
    private var backgroundLayer: some View { Color.white.ignoresSafeArea() }

    private var header: some View {
        VStack(spacing: 8) {
            Text("Step \(step) of 6")
                .font(.footnote)
                .foregroundStyle(.secondary)
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
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .tint(.black)
            }
            Spacer(minLength: 0)
            Button(action: {
                if step < 6 {
                    withAnimation { step += 1 }
                } else {
                    // Temporary: finish onboarding and hand off to paywall elsewhere
                    // We will present Adapty placement paywall from the root later
                    onFinish()
                }
            }) {
                HStack(spacing: 8) {
                    Text(step < 6 ? "Continue" : "Get started")
                        .font(.headline)
                    Image(systemName: step < 6 ? "arrow.right" : "creditcard")
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.black)
        }
    }

    // Removed card wrapper to keep steps full-screen on white background
    private func card(_ inner: some View) -> some View { inner }

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
                .foregroundStyle(.secondary)
            // Media placeholder (illustration)
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.secondary.opacity(0.08))
                .frame(height: 240)
                .overlay { Text("Illustration Placeholder") }
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
                .foregroundStyle(.secondary)
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
                .foregroundStyle(.secondary)
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
                .foregroundStyle(.secondary)
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
            Text("Share a letter-like image: ‘I’m committing to creating beautiful memories for a year & beyond.’")
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Generate & Share") {
                // Simple placeholder share card
                let renderer = ImageRenderer(content:
                    ZStack {
                        Color.white
                        VStack(spacing: 10) {
                            Text("Veramo Commitment")
                                .font(.title2).bold().foregroundColor(.black)
                            Text("I’m committing to creating beautiful memories for a year & beyond.")
                                .multilineTextAlignment(.center)
                                .foregroundColor(.black)
                                .padding()
                        }
                        .padding()
                    }
                    .frame(width: 800, height: 1000)
                )
                if let ui = renderer.uiImage { shareImage = ui; showingShareSheet = true }
            }
            .buttonStyle(.borderedProminent)
            .tint(.black)
        }
    }
}

// UIKit wrapper for share sheet
struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: activityItems, applicationActivities: nil) }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}


