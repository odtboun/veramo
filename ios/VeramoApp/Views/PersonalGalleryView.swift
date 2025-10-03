import SwiftUI

struct PersonalGalleryView: View {
    @State private var images: [String] = []
    @State private var selectedImage: String?
    @State private var showingCropView = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 8) {
                    ForEach(images, id: \.self) { imageUrl in
                        AsyncImage(url: URL(string: imageUrl)) { image in
                            image
                                .resizable()
                                .aspectRatio(1, contentMode: .fit)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        } placeholder: {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.ultraThinMaterial)
                                .aspectRatio(1, contentMode: .fit)
                                .overlay {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                }
                        }
                        .onTapGesture {
                            selectedImage = imageUrl
                            showingCropView = true
                        }
                        .contextMenu {
                            Button("Share to Calendar") {
                                selectedImage = imageUrl
                                showingCropView = true
                            }
                            
                            Button("Delete", role: .destructive) {
                                if let index = images.firstIndex(of: imageUrl) {
                                    images.remove(at: index)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
            .navigationTitle("My Gallery")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add Photo") {
                        addRandomImage()
                    }
                    .font(.headline)
                    .foregroundColor(.blue)
                }
            }
            .sheet(isPresented: $showingCropView) {
                if let imageUrl = selectedImage {
                    CropImageView(imageUrl: imageUrl) { croppedImage in
                        // Handle cropped image
                        images.append(croppedImage)
                        selectedImage = nil
                    }
                }
            }
            .onAppear {
                loadInitialImages()
            }
        }
    }
    
    private func loadInitialImages() {
        // Load 6 random images for initial gallery
        for _ in 0..<6 {
            addRandomImage()
        }
    }
    
    private func addRandomImage() {
        let randomId = Int.random(in: 1...1000)
        let imageUrl = "https://picsum.photos/400/400?random=\(randomId)"
        images.append(imageUrl)
    }
}

#Preview {
    PersonalGalleryView()
}
