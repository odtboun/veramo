import SwiftUI

struct OnboardingFlow: View {
    let partnerAlreadyOnboarded: Bool
    let onFinish: () -> Void
    @State private var step: Int = 1
    @State private var partnerName: String = ""
    @State private var relationshipStart: Date = Date()
    @State private var showingShareSheet: Bool = false
    @State private var shareImage: UIImage? = nil
    
    var body: some View {
        ZStack {
            LinearGradient(colors: [.pink.opacity(0.35), .orange.opacity(0.35)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Simple step indicator
                Text("Step \(step) of 6")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Group {
                    switch step {
                    case 1:
                        step1
                    case 2:
                        step2
                    case 3:
                        step3
                    case 4:
                        step4
                    case 5:
                        step5
                    default:
                        step6
                    }
                }
                .padding(20)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay { RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.25), lineWidth: 1) }
                .shadow(color: .pink.opacity(0.15), radius: 10, x: 0, y: 6)

                HStack {
                    if step > 1 { Button("Back") { withAnimation(.easeInOut) { step -= 1 } } }
                    Spacer()
                    Button(step < 6 ? "Continue" : "Finish") {
                        if step < 6 { withAnimation(.spring) { step += 1 } }
                        else { onFinish() }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.pink)
                }
            }
            .padding(20)
        }
        .sheet(isPresented: $showingShareSheet) {
            if let img = shareImage {
                ActivityView(activityItems: [img])
            }
        }
    }

    // MARK: - Steps
    private var step1: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("The Easiest Way to Build Your Shared Story.")
                .font(.title2).bold()
            Text("Turn everyday moments into a beautiful visual keepsake you both build over time.")
                .foregroundStyle(.secondary)
        }
    }

    private var step2: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Let’s personalize your experience")
                .font(.title3).bold()
            TextField("Partner's name", text: $partnerName)
                .textFieldStyle(.roundedBorder)
            DatePicker("When did your story begin?", selection: $relationshipStart, displayedComponents: .date)
        }
    }

    private var step3: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("A glimpse of the magic ✨")
                .font(.title3).bold()
            Text("We’ll show you how your memories can turn into stunning visuals in seconds.")
                .foregroundStyle(.secondary)
            RoundedRectangle(cornerRadius: 16)
                .fill(LinearGradient(colors: [.white.opacity(0.5), .white.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(height: 180)
                .overlay { Text("AI Preview Placeholder").foregroundStyle(.secondary) }
        }
    }

    private var step4: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your shared timeline")
                .font(.title3).bold()
            Text("Memories land on your shared calendar. Schedule gifts in advance and build anticipation together.")
                .foregroundStyle(.secondary)
            RoundedRectangle(cornerRadius: 16)
                .fill(.white.opacity(0.2))
                .frame(height: 160)
                .overlay { Text("Calendar Preview").foregroundStyle(.secondary) }
        }
    }

    private var step5: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Keep it visible with a widget")
                .font(.title3).bold()
            Text("See your latest memory on your Home Screen—stay connected daily without extra effort.")
                .foregroundStyle(.secondary)
            RoundedRectangle(cornerRadius: 16)
                .fill(.white.opacity(0.2))
                .frame(height: 160)
                .overlay { Text("Widget Preview").foregroundStyle(.secondary) }
        }
    }

    private var step6: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Invite your partner with a promise")
                .font(.title3).bold()
            Text("Share a letter-like image: ‘I’m committing to creating beautiful memories for a year & beyond.’")
                .foregroundStyle(.secondary)
            Button("Generate & Share") {
                // Simple placeholder share card
                let renderer = ImageRenderer(content:
                    ZStack {
                        LinearGradient(colors: [.pink, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
                        VStack(spacing: 8) {
                            Text("Veramo Commitment")
                                .font(.title2).bold().foregroundColor(.white)
                            Text("I’m committing to creating beautiful memories for a year & beyond.")
                                .multilineTextAlignment(.center)
                                .foregroundColor(.white)
                                .padding()
                        }
                        .padding()
                    }
                    .frame(width: 800, height: 1000)
                )
                if let ui = renderer.uiImage { shareImage = ui; showingShareSheet = true }
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
        }
    }
}

// UIKit wrapper for share sheet
struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: activityItems, applicationActivities: nil) }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}


