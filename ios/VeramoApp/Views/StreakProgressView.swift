import SwiftUI

struct StreakProgressView: View {
    @State private var currentStreak: Int = 0 // This would come from your data source
    
    private let milestones = [
        StreakMilestone(day: 7, title: "First Week", description: "You're building a beautiful habit!", reward: "Unlock special filters", isUnlocked: false),
        StreakMilestone(day: 14, title: "Two Weeks Strong", description: "Your love story is growing!", reward: "Premium photo effects", isUnlocked: false),
        StreakMilestone(day: 30, title: "Monthly Magic", description: "A month of beautiful memories!", reward: "Free Monthly Dump video", isUnlocked: false),
        StreakMilestone(day: 60, title: "Two Months Deep", description: "Your connection is deepening!", reward: "Anniversary animations", isUnlocked: false),
        StreakMilestone(day: 100, title: "Century Club", description: "100 days of love documented!", reward: "Custom celebration video", isUnlocked: false),
        StreakMilestone(day: 180, title: "Half Year Hero", description: "Six months of shared memories!", reward: "Birthday surprise animations", isUnlocked: false),
        StreakMilestone(day: 365, title: "Year of Love", description: "A full year of your journey!", reward: "Ultimate anniversary celebration", isUnlocked: false)
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 16) {
                        Text("Your Love Streak")
                            .font(.largeTitle.bold())
                            .foregroundColor(.primary)
                        
                        // Current streak display
                        ZStack {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.pink.opacity(0.8), Color.purple.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(height: 120)
                            
                            VStack(spacing: 8) {
                                Text("\(currentStreak)")
                                    .font(.system(size: 48, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                
                                Text("Days Strong")
                                    .font(.headline)
                                    .foregroundColor(.white.opacity(0.9))
                                
                                if currentStreak > 0 {
                                    Text("Keep it going! 💕")
                                        .font(.subheadline)
                                        .foregroundColor(.white.opacity(0.8))
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Timeline
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Milestone Journey")
                            .font(.title2.bold())
                            .foregroundColor(.primary)
                            .padding(.horizontal)
                        
                        LazyVStack(spacing: 16) {
                            ForEach(Array(milestones.enumerated()), id: \.offset) { index, milestone in
                                MilestoneCard(
                                    milestone: milestone,
                                    isCurrent: currentStreak >= milestone.day,
                                    isNext: currentStreak < milestone.day && (index == 0 || currentStreak >= milestones[index - 1].day)
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Bottom encouragement
                    VStack(spacing: 12) {
                        Text("Every day you share together")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("is a day worth celebrating")
                            .font(.title3.bold())
                            .foregroundColor(.primary)
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Streak Progress")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

struct StreakMilestone {
    let day: Int
    let title: String
    let description: String
    let reward: String
    let isUnlocked: Bool
}

struct MilestoneCard: View {
    let milestone: StreakMilestone
    let isCurrent: Bool
    let isNext: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            // Day number circle
            ZStack {
                Circle()
                    .fill(
                        isCurrent ? 
                        LinearGradient(colors: [Color.pink, Color.purple], startPoint: .topLeading, endPoint: .bottomTrailing) :
                        LinearGradient(colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 60, height: 60)
                
                Text("\(milestone.day)")
                    .font(.title2.bold())
                    .foregroundColor(isCurrent ? .white : .secondary)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(milestone.title)
                        .font(.headline.bold())
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    if isCurrent {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.title3)
                    } else if isNext {
                        Image(systemName: "star.circle.fill")
                            .foregroundColor(.orange)
                            .font(.title3)
                    }
                }
                
                Text(milestone.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                
                HStack {
                    Image(systemName: "gift.fill")
                        .foregroundColor(.pink)
                        .font(.caption)
                    
                    Text(milestone.reward)
                        .font(.caption.bold())
                        .foregroundColor(.pink)
                }
            }
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            isCurrent ? Color.pink.opacity(0.5) : Color.gray.opacity(0.2),
                            lineWidth: isCurrent ? 2 : 1
                        )
                )
        )
        .scaleEffect(isNext ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isNext)
    }
}

#Preview {
    StreakProgressView()
}
