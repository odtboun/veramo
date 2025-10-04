import SwiftUI

struct TodayView: View {
    @State private var todaysImage: String? = nil
    @State private var streakCount = 7
    @State private var hasMemory = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header with streak
                    VStack(spacing: 16) {
                        Text("Today")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        // Streak counter with liquid glass
                        HStack {
                            Image(systemName: "flame.fill")
                                .foregroundColor(.orange)
                            Text("\(streakCount) day streak")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(.ultraThinMaterial)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(.white.opacity(0.2), lineWidth: 1)
                                }
                        }
                    }
                    .padding(.top)
                    
                    // Today's memory
                    VStack(spacing: 16) {
                        Text("Today's Memory")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        if hasMemory, let imageUrl = todaysImage {
                            AsyncImage(url: URL(string: imageUrl)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(1, contentMode: .fit)
                                    .clipShape(RoundedRectangle(cornerRadius: 20))
                            } placeholder: {
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(.ultraThinMaterial)
                                    .aspectRatio(1, contentMode: .fit)
                                    .overlay {
                                        ProgressView()
                                            .scaleEffect(1.2)
                                    }
                            }
                            .frame(maxWidth: 300)
                            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                        } else {
                            // Empty state - Cute and inviting
                            VStack(spacing: 24) {
                                // Cute heart icon with sparkles
                                ZStack {
                                    Circle()
                                        .fill(.pink.opacity(0.1))
                                        .frame(width: 120, height: 120)
                                    
                                    VStack(spacing: 8) {
                                        Image(systemName: "heart.fill")
                                            .font(.system(size: 40))
                                            .foregroundColor(.pink)
                                        
                                        Image(systemName: "sparkles")
                                            .font(.system(size: 16))
                                            .foregroundColor(.yellow)
                                            .offset(x: 20, y: -10)
                                    }
                                }
                                
                                VStack(spacing: 12) {
                                    Text("No Memory Today")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.primary)
                                    
                                    Text("Capture a special moment and create your first memory together! 💕")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                        .lineLimit(3)
                                }
                                
                                // Cute decorative elements
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(.blue.opacity(0.3))
                                        .frame(width: 8, height: 8)
                                    Circle()
                                        .fill(.pink.opacity(0.3))
                                        .frame(width: 8, height: 8)
                                    Circle()
                                        .fill(.purple.opacity(0.3))
                                        .frame(width: 8, height: 8)
                                }
                            }
                            .padding(.vertical, 40)
                            .padding(.horizontal, 32)
                            .frame(maxWidth: 320)
                            .background {
                                RoundedRectangle(cornerRadius: 24)
                                    .fill(.ultraThinMaterial)
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 24)
                                            .stroke(
                                                LinearGradient(
                                                    colors: [.pink.opacity(0.3), .blue.opacity(0.3)],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                lineWidth: 1
                                            )
                                    }
                                    .shadow(color: .pink.opacity(0.1), radius: 10, x: 0, y: 5)
                            }
                        }
                    }
                    
                    // Action buttons
                    VStack(spacing: 12) {
                        Button(action: {
                            // Load today's memory from database
                            Task { await loadTodaysMemory() }
                        }) {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                Text("Refresh")
                            }
                            .font(.headline)
                            .foregroundColor(.primary)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(.ultraThinMaterial)
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(.white.opacity(0.2), lineWidth: 1)
                                    }
                            }
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: {
                            // Add new memory
                        }) {
                            HStack {
                                Image(systemName: "plus")
                                Text("Add Today's Memory")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(.blue)
                                    .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal)
                }
                .padding()
            }
            .background {
                // Subtle gradient background
                LinearGradient(
                    colors: [.clear, .blue.opacity(0.05)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .navigationBarHidden(true)
            .onAppear {
                Task { await loadTodaysMemory() }
            }
        }
    }
    
    private func loadTodaysMemory() async {
        // TODO: Load today's memory from calendar entries
        // For now, set empty state
        await MainActor.run {
            self.hasMemory = false
            self.todaysImage = nil
        }
    }
}

#Preview {
    TodayView()
}
