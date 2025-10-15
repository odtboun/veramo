import SwiftUI

struct StreakMilestone: Identifiable {
    let id = UUID()
    let day: Int
    let title: String
    let description: String
    let requirementText: String
    let isUnlocked: Bool
}

struct StreakProgressView: View {
    @State private var currentStreak: Int = 0
    @State private var navigateToAnimation: Bool = false
    
    private let milestones: [StreakMilestone] = [
        StreakMilestone(day: 0, title: "Generate Images in Any Style", description: "Create beautiful AI-generated images with any style you choose", requirementText: "Available Now", isUnlocked: true),
        StreakMilestone(day: 7, title: "Couple Podcast", description: "An audio podcast discussing your relationship", requirementText: "7+ day streak", isUnlocked: false),
        StreakMilestone(day: 30, title: "Monthly Summary", description: "AI-generated monthly relationship insights and highlights", requirementText: "30+ day streak", isUnlocked: false),
        StreakMilestone(day: 60, title: "Short Animation", description: "Personalized animations celebrating your milestones", requirementText: "60+ day streak", isUnlocked: true),
        StreakMilestone(day: 90, title: "Short Video", description: "A video podcast discussing your relationship", requirementText: "90+ day streak", isUnlocked: false),
        StreakMilestone(day: 180, title: "Longer Animation", description: "Extended personalized animations celebrating your milestones", requirementText: "180+ day streak", isUnlocked: false),
        StreakMilestone(day: 365, title: "Longer Video", description: "Extended video podcast discussing your relationship", requirementText: "365+ day streak", isUnlocked: false)
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Mascot placeholder spacing
                    Spacer().frame(height: 20)
                    
                    // Pink streak card
                    VStack(spacing: 8) {
                        Text("\(currentStreak)")
                            .font(.system(size: 44, weight: .bold))
                            .foregroundColor(.white)
                        Text("Days Streak")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(
                        LinearGradient(colors: [Color(red: 0.92, green: 0.85, blue: 0.33), Color(red: 0.81, green: 0.24, blue: 0.08)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .padding(.horizontal)
                    
                    Text("Increase your streak to unlock special features")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    
                    // Timeline
                    LazyVStack(spacing: 16) {
                        ForEach(milestones) { m in
                            Button {
                                if m.title == "Short Animation" && m.isUnlocked {
                                    navigateToAnimation = true
                                } else if m.title == "Generate Images in Any Style" && m.isUnlocked {
                                    NotificationCenter.default.post(name: NSNotification.Name("NavigateToCreateTab"), object: nil)
                                }
                            } label: {
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: m.isUnlocked ? "star.fill" : "lock.fill")
                                        .foregroundColor(m.isUnlocked ? Color.orange : Color.orange)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(m.title)
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        Text(m.description)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                        Text(m.requirementText)
                                            .font(.footnote.weight(.semibold))
                                            .foregroundColor(Color(red: 0.90, green: 0.59, blue: 0.17))
                                    }
                                    Spacer()
                                }
                                .padding(12)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 3)
                            }
                            .buttonStyle(.plain)
                            .disabled(!m.isUnlocked)
                            .padding(.horizontal)
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
            .background(Color.white)
            .navigationDestination(isPresented: $navigateToAnimation) {
                CreateAnimationView()
            }
        }
        .preferredColorScheme(.light)
    }
}

#Preview {
    StreakProgressView()
}


