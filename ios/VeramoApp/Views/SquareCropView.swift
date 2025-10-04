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
        print("📸 Capturing what's in the square...")
        
        // Create a 300x300 square image
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 300, height: 300))
        
        return renderer.image { context in
            // Clear background
            context.cgContext.setFillColor(UIColor.clear.cgColor)
            context.cgContext.fill(CGRect(x: 0, y: 0, width: 300, height: 300))
            
            // Calculate the image size and position to match what's displayed
            let imageAspectRatio = image.size.width / image.size.height
            let displayWidth: CGFloat
            let displayHeight: CGFloat
            
            if imageAspectRatio > 1.0 {
                // Image is wider - fit by height
                displayHeight = 300
                displayWidth = 300 * imageAspectRatio
            } else {
                // Image is taller - fit by width
                displayWidth = 300
                displayHeight = 300 / imageAspectRatio
            }
            
            // Apply user's scale
            let scaledWidth = displayWidth * scale
            let scaledHeight = displayHeight * scale
            
            // Calculate position with user's offset
            let x = (300 - scaledWidth) / 2 + offset.width
            let y = (300 - scaledHeight) / 2 + offset.height
            
            // Draw the image exactly as it appears
            image.draw(in: CGRect(x: x, y: y, width: scaledWidth, height: scaledHeight))
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
