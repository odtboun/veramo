import SwiftUI
import PhotosUI
import Supabase

struct PersonalGalleryView: View {
    struct GalleryItem: Identifiable, Hashable { 
        let id: UUID
        let url: URL
        let storagePath: String
        let fileName: String
        let createdAt: String
    }
    @State private var items: [GalleryItem] = []
    @State private var selected: GalleryItem?
    @State private var showingCropView = false
    @State private var photoSelection: PhotosPickerItem?
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Loading your gallery...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if items.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        
                        VStack(spacing: 8) {
                            Text("Your Gallery is Empty")
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            Text("Tap the + button to add your first photo")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                } else {
                    ScrollView {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 8) {
                            ForEach(items) { item in
                                AsyncImage(url: item.url) { image in
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
                                    selected = item
                                    showingCropView = true
                                }
                                .contextMenu {
                                    Button("Share to Calendar") {
                                        selected = item
                                        showingCropView = true
                                    }
                                    
                                    Button("Delete", role: .destructive) {
                                        Task { await deleteImage(item) }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .navigationTitle("My Gallery")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    PhotosPicker(selection: $photoSelection, matching: .images) {
                        HStack { Image(systemName: "plus"); Text("Add Photo") }
                    }
                }
            }
            .sheet(isPresented: $showingCropView) {
                if let selected {
                    CropImageView(imageUrl: selected.url.absoluteString) { _ in }
                }
            }
            .onAppear {
                Task { await fetchGallery() }
            }
            .onChange(of: photoSelection) { _, newValue in
                guard let newValue else { return }
                Task { await uploadPickedPhoto(newValue) }
            }
        }
    }
    
    private func fetchGallery() async {
        await MainActor.run { self.isLoading = true }
        
        do {
            let uploads = try await SupabaseService.shared.getGalleryUploads()
            let signed = try await withThrowingTaskGroup(of: GalleryItem?.self) { group -> [GalleryItem] in
                for upload in uploads {
                    group.addTask {
                        let url = try await SupabaseService.shared.getSignedImageURL(storagePath: upload.storage_path)
                        return GalleryItem(
                            id: upload.id,
                            url: URL(string: url)!,
                            storagePath: upload.storage_path,
                            fileName: upload.file_name,
                            createdAt: upload.created_at
                        )
                    }
                }
                var out: [GalleryItem] = []
                for try await v in group { if let v { out.append(v) } }
                return out
            }
            await MainActor.run { 
                self.items = signed
                self.isLoading = false
            }
        } catch { 
            print("Fetch gallery failed: \(error)")
            await MainActor.run { 
                self.isLoading = false
                self.errorMessage = "Failed to load gallery: \(error.localizedDescription)"
            }
        }
    }

    private func uploadPickedPhoto(_ item: PhotosPickerItem) async {
        print("🔄 Starting photo upload...")
        await MainActor.run { self.isLoading = true }
        
        do {
            print("📱 Loading data from PhotosPickerItem...")
            guard let data = try await item.loadTransferable(type: Data.self) else { 
                print("❌ Failed to load data from PhotosPickerItem")
                await MainActor.run { self.isLoading = false }
                return 
            }
            print("✅ Data loaded: \(data.count) bytes")
            
            // Get image metadata
            guard let image = UIImage(data: data) else {
                print("❌ Failed to create UIImage from data")
                await MainActor.run { self.isLoading = false }
                return
            }
            print("✅ Image created: \(image.size.width)x\(image.size.height)")
            
            let fileName = "\(UUID().uuidString).jpg"
            print("📝 File name: \(fileName)")
            
            print("🔑 Getting signed upload URL...")
            let signedURL = try await SupabaseService.shared.getSignedUploadURL(fileName: fileName, mimeType: "image/jpeg")
            print("✅ Signed URL received: \(signedURL.signedURL)")
            
            // Upload to storage
            print("☁️ Uploading to Supabase Storage...")
            try await SupabaseService.shared.uploadImageToStorage(data: data, signedURL: signedURL.signedURL)
            print("✅ Upload to storage successful")
            
            // Save to database
            print("💾 Saving to database...")
            try await SupabaseService.shared.saveGalleryUpload(
                storagePath: signedURL.path,
                fileName: fileName,
                fileSize: Int64(data.count),
                mimeType: "image/jpeg",
                width: Int(image.size.width),
                height: Int(image.size.height)
            )
            print("✅ Database save successful")
            
            print("🔄 Refreshing gallery...")
            await fetchGallery()
            print("✅ Upload complete!")
            
        } catch { 
            print("❌ Upload failed: \(error)")
            print("❌ Error details: \(error.localizedDescription)")
            await MainActor.run { 
                self.isLoading = false
                self.errorMessage = "Upload failed: \(error.localizedDescription)"
            }
        }
    }
    
    private func deleteImage(_ item: GalleryItem) async {
        do {
            // Delete from storage
            try await SupabaseService.shared.client.storage
                .from("user-uploads")
                .remove(paths: [item.storagePath])
            
            // Delete from database
            try await SupabaseService.shared.client
                .from("gallery_uploads")
                .delete()
                .eq("id", value: item.id)
                .execute()
            
            await fetchGallery()
        } catch {
            print("Delete failed: \(error)")
            await MainActor.run {
                self.errorMessage = "Delete failed: \(error.localizedDescription)"
            }
        }
    }
}

#Preview {
    PersonalGalleryView()
}
