import SwiftUI

struct CropImageView: View {
    let imageUrl: String
    let onCrop: (String) -> Void
    
    @State private var cropRect = CGRect(x: 0, y: 0, width: 200, height: 200)
    @State private var imageSize = CGSize(width: 400, height: 400)
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Crop to Square")
                    .font(.headline)
                    .padding(.top)
                
                // Image cropping interface
                ZStack {
                    AsyncImage(url: URL(string: imageUrl)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: 300, maxHeight: 300)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
                            .frame(width: 300, height: 300)
                            .overlay {
                                ProgressView()
                            }
                    }
                    
                    // Crop overlay
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.blue, lineWidth: 2)
                        .frame(width: 200, height: 200)
                        .overlay {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.blue.opacity(0.1))
                        }
                }
                
                Text("Drag to adjust crop area")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // Action buttons
                HStack(spacing: 16) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
                    }
                    
                    Button("Crop & Save") {
                        // For now, just return the original image
                        // In a real app, you'd implement actual cropping
                        onCrop(imageUrl)
                        dismiss()
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.blue)
                            .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                }
                .padding(.horizontal)
            }
            .padding()
            .navigationBarHidden(true)
        }
    }
}

#Preview {
    CropImageView(imageUrl: "https://picsum.photos/400/400") { croppedImage in
        print("Cropped image: \(croppedImage)")
    }
}
