import SwiftUI

struct SquareCropView: View {
    let image: UIImage
    let onCrop: (UIImage) -> Void
    let onCancel: () -> Void
    
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastScale: CGFloat = 1.0
    @State private var lastOffset: CGSize = .zero
    
    private let cropSize: CGFloat = 300 // Square crop size
    
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
                                            let newOffset = CGSize(
                                                width: lastOffset.width + value.translation.width,
                                                height: lastOffset.height + value.translation.height
                                            )
                                            
                                            // Calculate image size after scaling
                                            let imageAspectRatio = image.size.width / image.size.height
                                            let frameAspectRatio: CGFloat = 1.0 // Square frame
                                            
                                            let imageDisplaySize: CGSize
                                            if imageAspectRatio > frameAspectRatio {
                                                // Image is wider than square - fit by height
                                                imageDisplaySize = CGSize(
                                                    width: cropSize * imageAspectRatio,
                                                    height: cropSize
                                                )
                                            } else {
                                                // Image is taller than square - fit by width
                                                imageDisplaySize = CGSize(
                                                    width: cropSize,
                                                    height: cropSize / imageAspectRatio
                                                )
                                            }
                                            
                                            let scaledImageSize = CGSize(
                                                width: imageDisplaySize.width * scale,
                                                height: imageDisplaySize.height * scale
                                            )
                                            
                                            // Calculate max offset to keep image within bounds
                                            let maxOffsetX = max(0, (scaledImageSize.width - cropSize) / 2)
                                            let maxOffsetY = max(0, (scaledImageSize.height - cropSize) / 2)
                                            
                                            offset = CGSize(
                                                width: max(-maxOffsetX, min(maxOffsetX, newOffset.width)),
                                                height: max(-maxOffsetY, min(maxOffsetY, newOffset.height))
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
        
        // Calculate the actual crop area in the original image coordinates
        let imageSize = image.size
        let imageAspectRatio = imageSize.width / imageSize.height
        
        // Calculate how the image is displayed in the square frame
        let displaySize: CGSize
        if imageAspectRatio > 1.0 {
            // Image is wider than square - fit by height
            displaySize = CGSize(width: cropSize * imageAspectRatio, height: cropSize)
        } else {
            // Image is taller than square - fit by width  
            displaySize = CGSize(width: cropSize, height: cropSize / imageAspectRatio)
        }
        
        // Calculate the scaled display size
        let scaledDisplaySize = CGSize(
            width: displaySize.width * scale,
            height: displaySize.height * scale
        )
        
        // Calculate the crop rectangle in the original image coordinates
        let scaleFactor = imageSize.width / displaySize.width
        let cropRectInImage = CGRect(
            x: (displaySize.width - cropSize) / 2 * scaleFactor - offset.width * scaleFactor,
            y: (displaySize.height - cropSize) / 2 * scaleFactor - offset.height * scaleFactor,
            width: cropSize * scaleFactor,
            height: cropSize * scaleFactor
        )
        
        // Ensure crop rect is within image bounds
        let clampedRect = CGRect(
            x: max(0, min(imageSize.width - cropSize * scaleFactor, cropRectInImage.minX)),
            y: max(0, min(imageSize.height - cropSize * scaleFactor, cropRectInImage.minY)),
            width: min(cropSize * scaleFactor, imageSize.width),
            height: min(cropSize * scaleFactor, imageSize.height)
        )
        
        print("🎯 Crop rect: \(clampedRect)")
        
        // Perform the actual crop
        guard let cgImage = image.cgImage?.cropping(to: clampedRect) else {
            print("❌ Crop failed, using original image")
            return image // Fallback to original if crop fails
        }
        
        // Create the final square image
        let finalImage = UIImage(cgImage: cgImage)
        print("✅ Cropped image size: \(finalImage.size)")
        
        // Resize to exact square size if needed
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: cropSize, height: cropSize))
        let result = renderer.image { _ in
            finalImage.draw(in: CGRect(x: 0, y: 0, width: cropSize, height: cropSize))
        }
        
        print("🎉 Final square image size: \(result.size)")
        return result
    }
}

#Preview {
    SquareCropView(
        image: UIImage(systemName: "photo")!,
        onCrop: { _ in },
        onCancel: { }
    )
}
