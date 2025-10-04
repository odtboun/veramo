import SwiftUI

struct SquareCropView: View {
    let image: UIImage
    let onCrop: (UIImage) -> Void
    let onCancel: () -> Void
    
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastScale: CGFloat = 1.0
    @State private var lastOffset: CGSize = .zero
    
    init(image: UIImage, onCrop: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
        self.image = image
        self.onCrop = onCrop
        self.onCancel = onCancel
        
        // Initialize scale to fill the square
        let imageAspectRatio = image.size.width / image.size.height
        if imageAspectRatio > 1.0 {
            // Image is wider - it will fit by height, so scale = 1.0 is correct
            _scale = State(initialValue: 1.0)
        } else {
            // Image is taller - it will fit by width, so scale = 1.0 is correct
            _scale = State(initialValue: 1.0)
        }
        _lastScale = State(initialValue: 1.0)
    }
    
    private let cropSize: CGFloat = 300 // Square crop size
    
    // Calculate initial scale to fill the square
    private var initialScale: CGFloat {
        let imageAspectRatio = image.size.width / image.size.height
        if imageAspectRatio > 1.0 {
            // Image is wider - fit by height
            return 1.0
        } else {
            // Image is taller - fit by width
            return 1.0
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Crop to Square")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.top)
                
                Text("Adjust the photo to fit the square frame")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                // Crop area
                ZStack {
                    // Background
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .frame(width: cropSize, height: cropSize)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(.blue, lineWidth: 2)
                        }
                    
                    // Image with crop overlay
                    GeometryReader { geometry in
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .scaleEffect(scale)
                            .offset(offset)
                            .gesture(
                                SimultaneousGesture(
                                    MagnificationGesture()
                                        .onChanged { value in
                                            scale = lastScale * value
                                        }
                                        .onEnded { value in
                                            lastScale = scale
                                            // Constrain scale
                                            if scale < 0.5 { scale = 0.5; lastScale = 0.5 }
                                            if scale > 3.0 { scale = 3.0; lastScale = 3.0 }
                                        },
                                    
                                    DragGesture()
                                        .onChanged { value in
                                            offset = CGSize(
                                                width: lastOffset.width + value.translation.width,
                                                height: lastOffset.height + value.translation.height
                                            )
                                        }
                                        .onEnded { value in
                                            lastOffset = offset
                                        }
                                )
                            )
                    }
                    .frame(width: cropSize, height: cropSize)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .frame(width: cropSize, height: cropSize)
                
                // Instructions
                VStack(spacing: 8) {
                    Text("Pinch to zoom • Drag to move")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Make sure the important part is in the square")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Action buttons
                HStack(spacing: 16) {
                    Button("Cancel", action: onCancel)
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.ultraThinMaterial)
                        }
                    
                    Button("Use This Crop", action: {
                        let croppedImage = cropImageToSquare()
                        onCrop(croppedImage)
                    })
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.blue)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationBarHidden(true)
        }
    }
    
    private func cropImageToSquare() -> UIImage {
        print("🔪 Starting square crop...")
        print("📐 Original image size: \(image.size)")
        print("📏 Scale: \(scale), Offset: \(offset)")
        
        // Create a renderer that captures exactly what's visible in the square
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: cropSize, height: cropSize))
        
        return renderer.image { context in
            // Clear the background
            context.cgContext.clear(CGRect(x: 0, y: 0, width: cropSize, height: cropSize))
            
            // Calculate how the image should be drawn to match the display
            let imageSize = image.size
            let imageAspectRatio = imageSize.width / imageSize.height
            
            // Calculate the display size (same logic as SwiftUI's aspectRatio: .fit)
            let displaySize: CGSize
            if imageAspectRatio > 1.0 {
                // Image is wider - fit by height
                displaySize = CGSize(width: cropSize * imageAspectRatio, height: cropSize)
            } else {
                // Image is taller - fit by width
                displaySize = CGSize(width: cropSize, height: cropSize / imageAspectRatio)
            }
            
            // Apply the user's scale and offset
            let scaledDisplaySize = CGSize(
                width: displaySize.width * scale,
                height: displaySize.height * scale
            )
            
            // Calculate where to draw the image to match the user's view
            let drawRect = CGRect(
                x: (cropSize - scaledDisplaySize.width) / 2 + offset.width,
                y: (cropSize - scaledDisplaySize.height) / 2 + offset.height,
                width: scaledDisplaySize.width,
                height: scaledDisplaySize.height
            )
            
            print("📐 Display size: \(displaySize)")
            print("📏 Scaled display size: \(scaledDisplaySize)")
            print("🎯 Draw rect: \(drawRect)")
            
            // Draw the image exactly as it appears in the view
            image.draw(in: drawRect)
        }
    }
}

#Preview {
    SquareCropView(
        image: UIImage(systemName: "photo")!,
        onCrop: { _ in },
        onCancel: { }
    )
}
