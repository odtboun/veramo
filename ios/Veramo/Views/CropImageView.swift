import SwiftUI

struct CropImageView: View {
    let imageUrl: String
    let onCropComplete: (String) -> Void
    
    @State private var cropRect = CGRect(x: 0, y: 0, width: 200, height: 200)
    @State private var imageSize = CGSize(width: 400, height: 400)
    @State private var showingImage = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Instructions
                VStack(spacing: 8) {
                    Text("Crop to Square")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Calendar images must be square. Adjust the crop area below.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal)
                
                // Image with crop overlay
                ZStack {
                    AsyncImage(url: URL(string: imageUrl)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .onAppear {
                                showingImage = true
                            }
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
                            .aspectRatio(1, contentMode: .fit)
                            .overlay {
                                ProgressView()
                                    .scaleEffect(1.2)
                            }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    // Crop overlay
                    if showingImage {
                        CropOverlayView(cropRect: $cropRect, imageSize: imageSize)
                    }
                }
                .frame(maxHeight: 400)
                .padding(.horizontal)
                
                // Crop controls
                VStack(spacing: 16) {
                    Text("Adjust the square to select your crop area")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 20) {
                        Button("Reset") {
                            resetCrop()
                        }
                        .font(.headline)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.ultraThinMaterial)
                        }
                        
                        Button("Crop & Share") {
                            cropAndShare()
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.blue)
                                .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func resetCrop() {
        // Reset crop to center
        let size = min(imageSize.width, imageSize.height)
        cropRect = CGRect(
            x: (imageSize.width - size) / 2,
            y: (imageSize.height - size) / 2,
            width: size,
            height: size
        )
    }
    
    private func cropAndShare() {
        // For now, just return the original image URL
        // In a real implementation, you'd crop the image and return the new URL
        onCropComplete(imageUrl)
        dismiss()
    }
}

struct CropOverlayView: View {
    @Binding var cropRect: CGRect
    let imageSize: CGSize
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Dark overlay
                Rectangle()
                    .fill(.black.opacity(0.5))
                
                // Clear crop area
                Rectangle()
                    .frame(width: cropRect.width, height: cropRect.height)
                    .position(x: cropRect.midX, y: cropRect.midY)
                    .blendMode(.destinationOut)
                
                // Crop border
                Rectangle()
                    .stroke(.white, lineWidth: 2)
                    .frame(width: cropRect.width, height: cropRect.height)
                    .position(x: cropRect.midX, y: cropRect.midY)
            }
            .compositingGroup()
            .onTapGesture { location in
                updateCropRect(for: location, in: geometry.size)
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        updateCropRect(for: value.location, in: geometry.size)
                    }
            )
        }
    }
    
    private func updateCropRect(for location: CGPoint, in size: CGSize) {
        let squareSize: CGFloat = 200
        let newX = max(0, min(location.x - squareSize/2, size.width - squareSize))
        let newY = max(0, min(location.y - squareSize/2, size.height - squareSize))
        
        cropRect = CGRect(x: newX, y: newY, width: squareSize, height: squareSize)
    }
}

#Preview {
    CropImageView(imageUrl: "https://picsum.photos/400/400") { _ in }
}
