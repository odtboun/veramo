import SwiftUI
import PhotosUI
import Supabase

struct PersonalGalleryView: View {
    struct GalleryItem: Identifiable, Hashable { let id: UUID = .init(); let url: URL; let storagePath: String }
    @State private var items: [GalleryItem] = []
    @State private var selected: GalleryItem?
    @State private var showingCropView = false
    @State private var photoSelection: PhotosPickerItem?
    
    var body: some View {
        NavigationView {
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
                                if let idx = items.firstIndex(of: item) { items.remove(at: idx) }
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
        do {
            let user = try await SupabaseService.shared.client.auth.session.user
            struct Img: Decodable { let storage_path: String }
            let rows: [Img] = try await SupabaseService.shared.client
                .from("images")
                .select("storage_path")
                .eq("owner_id", value: user.id)
                .order("created_at", ascending: false)
                .execute().value
            let signed = try await withThrowingTaskGroup(of: GalleryItem?.self) { group -> [GalleryItem] in
                for row in rows {
                    group.addTask {
                        let url = try await SupabaseService.shared.client.storage
                            .from(SupabaseService.shared.imagesBucket)
                            .createSignedURL(path: row.storage_path, expiresIn: 3600)
                        return GalleryItem(url: url, storagePath: row.storage_path)
                    }
                }
                var out: [GalleryItem] = []
                for try await v in group { if let v { out.append(v) } }
                return out
            }
            await MainActor.run { self.items = signed }
        } catch { print("Fetch gallery failed: \(error)") }
    }

    private func uploadPickedPhoto(_ item: PhotosPickerItem) async {
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else { return }
            let user = try await SupabaseService.shared.client.auth.session.user
            let fileName = "\(user.id)/\(UUID().uuidString).jpg"
            try await SupabaseService.shared.client.storage
                .from(SupabaseService.shared.imagesBucket)
                .upload(fileName, data: data, options: FileOptions(contentType: "image/jpeg"))
            struct NewImage: Encodable { let owner_id: UUID; let storage_path: String }
            _ = try await SupabaseService.shared.client
                .from("images")
                .insert(NewImage(owner_id: user.id, storage_path: fileName))
                .execute()
            await fetchGallery()
        } catch { print("Upload failed: \(error)") }
    }
}

#Preview {
    PersonalGalleryView()
}
