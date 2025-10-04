import SwiftUI
import PhotosUI
import Supabase

struct PersonalGalleryView: View {
    struct GalleryItem: Identifiable, Hashable { 
        let id: UUID
        let url: URL?
        let localImage: UIImage?
        let storagePath: String?
        let fileName: String
        let createdAt: String
        let isSynced: Bool
        let isUploading: Bool
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
                                GalleryItemView(
                                    item: item,
                                    onTap: { selected = item; showingCropView = true },
                                    onDelete: { Task { await deleteImage(item) } }
                                )
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
                    ImagePreviewView(item: selected) {
                        showingCropView = false
                    }
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
        print("🔄 Fetching gallery...")
        await MainActor.run { self.isLoading = true }
        
        do {
            let uploads = try await SupabaseService.shared.getGalleryUploads()
            print("📸 Found \(uploads.count) uploads in database")
            
            let signed = try await withThrowingTaskGroup(of: GalleryItem?.self) { group -> [GalleryItem] in
                for upload in uploads {
                    group.addTask {
                        do {
                            print("🔗 Getting signed URL for: \(upload.storage_path)")
                            let url = try await SupabaseService.shared.getSignedImageURL(storagePath: upload.storage_path)
                            print("✅ Signed URL created for: \(upload.storage_path)")
                            return GalleryItem(
                                id: upload.id,
                                url: URL(string: url),
                                localImage: nil,
                                storagePath: upload.storage_path,
                                fileName: upload.file_name,
                                createdAt: upload.created_at,
                                isSynced: true,
                                isUploading: false
                            )
                        } catch {
                            print("❌ Failed to get signed URL for \(upload.storage_path): \(error)")
                            return nil
                        }
                    }
                }
                var out: [GalleryItem] = []
                for try await v in group { 
                    if let v { 
                        out.append(v)
                        print("✅ Added gallery item: \(v.fileName)")
                    }
                }
                return out
            }
            
            print("📱 Gallery items ready: \(signed.count)")
            await MainActor.run { 
                // Merge with existing local items, avoiding duplicates
                let existingLocalItems = self.items.filter { $0.localImage != nil }
                let syncedItems = signed.filter { remoteItem in
                    !existingLocalItems.contains { $0.fileName == remoteItem.fileName }
                }
                self.items = existingLocalItems + syncedItems
                self.isLoading = false
            }
        } catch { 
            print("❌ Fetch gallery failed: \(error)")
            await MainActor.run { 
                self.isLoading = false
                self.errorMessage = "Failed to load gallery: \(error.localizedDescription)"
            }
        }
    }

    private func uploadPickedPhoto(_ item: PhotosPickerItem) async {
        print("🔄 Starting photo upload...")
        
        do {
            print("📱 Loading data from PhotosPickerItem...")
            guard let data = try await item.loadTransferable(type: Data.self) else { 
                print("❌ Failed to load data from PhotosPickerItem")
                return 
            }
            print("✅ Data loaded: \(data.count) bytes")
            
            // Get image metadata
            guard let image = UIImage(data: data) else {
                print("❌ Failed to create UIImage from data")
                return
            }
            print("✅ Image created: \(image.size.width)x\(image.size.height)")
            
            // Create local gallery item immediately
            let localItem = GalleryItem(
                id: UUID(),
                url: nil,
                localImage: image,
                storagePath: nil,
                fileName: "\(UUID().uuidString).jpg",
                createdAt: ISO8601DateFormatter().string(from: Date()),
                isSynced: false,
                isUploading: true
            )
            
            // Add to gallery immediately
            await MainActor.run {
                self.items.insert(localItem, at: 0)
                self.isLoading = false
            }
            
            print("📱 Image added to gallery locally")
            
            // Upload to Supabase in background
            Task {
                await uploadToSupabase(localItem: localItem, data: data, image: image)
            }
            
        } catch { 
            print("❌ Upload failed: \(error)")
            print("❌ Error details: \(error.localizedDescription)")
            await MainActor.run { 
                self.isLoading = false
                self.errorMessage = "Upload failed: \(error.localizedDescription)"
            }
        }
    }
    
    private func uploadToSupabase(localItem: GalleryItem, data: Data, image: UIImage) async {
        do {
            let userId = try await SupabaseService.shared.currentUserId()
            let fileName = "\(userId)/\(UUID().uuidString).jpg"
            print("📝 File name: \(fileName)")
            
            // Upload directly to Supabase Storage
            print("☁️ Uploading to Supabase Storage...")
            try await SupabaseService.shared.client.storage
                .from("user-uploads")
                .upload(fileName, data: data, options: FileOptions(contentType: "image/jpeg"))
            print("✅ Upload to storage successful")
            
            // Save to database
            print("💾 Saving to database...")
            try await SupabaseService.shared.saveGalleryUpload(
                storagePath: fileName,
                fileName: fileName.components(separatedBy: "/").last ?? fileName,
                fileSize: Int64(data.count),
                mimeType: "image/jpeg",
                width: Int(image.size.width),
                height: Int(image.size.height)
            )
            print("✅ Database save successful")
            
            // Update local item to show as synced
            await MainActor.run {
                if let index = self.items.firstIndex(where: { $0.id == localItem.id }) {
                    self.items[index] = GalleryItem(
                        id: localItem.id,
                        url: nil, // Will be fetched from database
                        localImage: localItem.localImage,
                        storagePath: fileName,
                        fileName: localItem.fileName,
                        createdAt: localItem.createdAt,
                        isSynced: true,
                        isUploading: false
                    )
                }
            }
            
            print("✅ Background upload complete!")
            
        } catch {
            print("❌ Background upload failed: \(error)")
            // Update local item to show upload failed
            await MainActor.run {
                if let index = self.items.firstIndex(where: { $0.id == localItem.id }) {
                    self.items[index] = GalleryItem(
                        id: localItem.id,
                        url: nil,
                        localImage: localItem.localImage,
                        storagePath: nil,
                        fileName: localItem.fileName,
                        createdAt: localItem.createdAt,
                        isSynced: false,
                        isUploading: false
                    )
                }
            }
        }
    }
    
    private func deleteImage(_ item: GalleryItem) async {
        do {
            // Delete from storage if it exists
            if let storagePath = item.storagePath {
                try await SupabaseService.shared.client.storage
                    .from("user-uploads")
                    .remove(paths: [storagePath])
            }
            
            // Delete from database
            try await SupabaseService.shared.client
                .from("gallery_uploads")
                .delete()
                .eq("id", value: item.id)
                .execute()
            
            // Remove from local items
            await MainActor.run {
                self.items.removeAll { $0.id == item.id }
            }
        } catch {
            print("Delete failed: \(error)")
            await MainActor.run {
                self.errorMessage = "Delete failed: \(error.localizedDescription)"
            }
        }
    }
}

struct GalleryItemView: View {
    let item: PersonalGalleryView.GalleryItem
    let onTap: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        ZStack {
            // Show local image if available, otherwise remote
            if let localImage = item.localImage {
                Image(uiImage: localImage)
                    .resizable()
                    .aspectRatio(1, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else if let url = item.url {
                AsyncImage(url: url) { image in
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
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .aspectRatio(1, contentMode: .fit)
                    .overlay {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
            }
            
            // Upload status indicator
            VStack {
                HStack {
                    Spacer()
                    if item.isUploading {
                        ProgressView()
                            .scaleEffect(0.7)
                            .padding(8)
                            .background(.ultraThinMaterial, in: Circle())
                    } else if !item.isSynced {
                        Image(systemName: "icloud.and.arrow.up")
                            .font(.caption)
                            .foregroundColor(.orange)
                            .padding(8)
                            .background(.ultraThinMaterial, in: Circle())
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                            .padding(8)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                }
                Spacer()
            }
            .padding(8)
        }
        .onTapGesture(perform: onTap)
        .contextMenu {
            Button("Add to Calendar") { onTap() }
            Button("Delete", role: .destructive, action: onDelete)
        }
    }
}

struct ImagePreviewView: View {
    let item: PersonalGalleryView.GalleryItem
    let onDismiss: () -> Void
    @State private var showingCalendarPicker = false
    @State private var selectedDate = Date()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Full-size image preview
                if let localImage = item.localImage {
                    Image(uiImage: localImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                } else if let url = item.url {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                            .aspectRatio(1, contentMode: .fit)
                            .overlay {
                                ProgressView()
                                    .scaleEffect(1.2)
                            }
                    }
                }
                
                // Action buttons
                VStack(spacing: 16) {
                    Button(action: { showingCalendarPicker = true }) {
                        HStack {
                            Image(systemName: "calendar")
                            Text("Add to Calendar")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.blue)
                        }
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: onDismiss) {
                        Text("Close")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
            }
            .padding()
            .navigationTitle("Image Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done", action: onDismiss)
                }
            }
        }
        .sheet(isPresented: $showingCalendarPicker) {
            CalendarDatePickerView(
                selectedDate: $selectedDate,
                onConfirm: { date in
                    Task { await addToCalendar(date: date) }
                }
            )
        }
    }
    
    private func addToCalendar(date: Date) async {
        do {
            // Get the image ID from the database
            let uploads = try await SupabaseService.shared.getGalleryUploads()
            if let matchingUpload = uploads.first(where: { $0.file_name == item.fileName }) {
                try await SupabaseService.shared.addCalendarEntry(
                    imageId: matchingUpload.id,
                    scheduledDate: date
                )
                print("✅ Added to calendar for \(date)")
            }
            onDismiss()
        } catch {
            print("❌ Failed to add to calendar: \(error)")
        }
    }
}

struct CalendarDatePickerView: View {
    @Binding var selectedDate: Date
    let onConfirm: (Date) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Choose Date for Calendar")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.top)
                
                DatePicker(
                    "Select Date",
                    selection: $selectedDate,
                    in: Date()...,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.graphical)
                .padding()
                
                Button(action: { onConfirm(selectedDate) }) {
                    Text("Add to Calendar")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.blue)
                        }
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle("Schedule Memory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel", action: { dismiss() })
                }
            }
        }
    }
}

#Preview {
    PersonalGalleryView()
}
