import SwiftUI

struct CreateMemoryView: View {
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 16) {
                        Text("Create New Memory")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Choose how you'd like to create your memory")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top)
                    
                    // Creation options
                    VStack(spacing: 20) {
                        // AI Generation
                        CreateOptionCard(
                            icon: "sparkles",
                            title: "AI Generation",
                            description: "Create unique images with AI using text prompts",
                            color: .purple
                        ) {
                            // Navigate to AI generation
                        }
                        
                        // Upload Photo
                        CreateOptionCard(
                            icon: "photo",
                            title: "Upload Photo",
                            description: "Add a photo from your camera or library",
                            color: .blue
                        ) {
                            // Navigate to photo picker
                        }
                        
                        // Edit Existing
                        CreateOptionCard(
                            icon: "pencil.and.outline",
                            title: "Edit Existing",
                            description: "Edit images from your gallery",
                            color: .green
                        ) {
                            // Navigate to gallery
                        }
                    }
                    .padding(.horizontal)
                    
                    // Recent creations preview
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Recent Creations")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .padding(.horizontal)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(0..<5) { index in
                                    AsyncImage(url: URL(string: "https://picsum.photos/150/150?random=\(index)")) { image in
                                        image
                                            .resizable()
                                            .aspectRatio(1, contentMode: .fit)
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                    } placeholder: {
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(.ultraThinMaterial)
                                            .aspectRatio(1, contentMode: .fit)
                                    }
                                    .frame(width: 100, height: 100)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding()
            }
            .background {
                LinearGradient(
                    colors: [.clear, .purple.opacity(0.05)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .navigationBarHidden(true)
        }
    }
}

struct CreateOptionCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                    .frame(width: 40, height: 40)
                    .background {
                        Circle()
                            .fill(color.opacity(0.1))
                    }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(description)
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
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(.white.opacity(0.2), lineWidth: 1)
                    }
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    CreateMemoryView()
}
