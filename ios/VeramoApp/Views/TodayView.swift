import SwiftUI

struct TodayView: View {
    @State private var todaysImage: String = "https://picsum.photos/400/400"
    @State private var streakCount = 7
    
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
                    
                    // Today's image
                    VStack(spacing: 16) {
                        Text("Today's Memory")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        AsyncImage(url: URL(string: todaysImage)) { image in
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
                    }
                    
                    // Action buttons
                    VStack(spacing: 12) {
                        Button(action: {
                            // Refresh today's image
                            todaysImage = "https://picsum.photos/400/400?random=\(Int.random(in: 1...1000))"
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
        }
    }
}

#Preview {
    TodayView()
}
