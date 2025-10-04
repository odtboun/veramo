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
                            .clipped()
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
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: cropSize, height: cropSize))
        
        return renderer.image { context in
            // Calculate the crop area based on current scale and offset
            let imageSize = image.size
            let scaleFactor = max(imageSize.width / cropSize, imageSize.height / cropSize) / scale
            
            let cropX = (imageSize.width - cropSize * scaleFactor) / 2 - offset.width * scaleFactor
            let cropY = (imageSize.height - cropSize * scaleFactor) / 2 - offset.height * scaleFactor
            
            let cropRect = CGRect(
                x: max(0, cropX),
                y: max(0, cropY),
                width: min(imageSize.width, cropSize * scaleFactor),
                height: min(imageSize.height, cropSize * scaleFactor)
            )
            
            if let cgImage = image.cgImage?.cropping(to: cropRect) {
                let croppedImage = UIImage(cgImage: cgImage)
                croppedImage.draw(in: CGRect(x: 0, y: 0, width: cropSize, height: cropSize))
            }
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
