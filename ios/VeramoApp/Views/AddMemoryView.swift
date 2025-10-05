import SwiftUI
import PhotosUI
import Supabase

struct AddMemoryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedDate = Date()
    @State private var showingDatePicker = false
    @State private var photoSelection: PhotosPickerItem?
    @State private var showingSquareCrop = false
    @State private var imageForCropping: UIImage?
    @State private var croppedImage: UIImage?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 16) {
                    Text("Add Memory")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Choose how you'd like to create your memory")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top)
                
                // Options
                VStack(spacing: 20) {
                    // Upload from Device
                    PhotosPicker(selection: $photoSelection, matching: .images) {
                        HStack(spacing: 16) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.title2)
                                .foregroundColor(.blue)
                                .frame(width: 40)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Upload from Device")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text("Select a photo from your camera roll")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.ultraThinMaterial)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 16)
                                .stroke(Branding.primaryWarm.opacity(0.3), lineWidth: 1)
                                }
                        }
                    }
                    .buttonStyle(.plain)
                    
                    // AI Generate
                    Button(action: {
                        NotificationCenter.default.post(name: NSNotification.Name("NavigateToCreateTab"), object: nil)
                        dismiss()
                    }) {
                        HStack(spacing: 16) {
                            Image(systemName: "sparkles")
                                .font(.title2)
                                .foregroundColor(.purple)
                                .frame(width: 40)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Generate with AI")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text("Create an image with AI")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.ultraThinMaterial)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 16)
                                .stroke(Branding.accentWarm.opacity(0.3), lineWidth: 1)
                                }
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(false)
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle("Add Memory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel", action: { dismiss() })
                }
            }
        }
        .onChange(of: photoSelection) { _, newValue in
            guard let newValue else { return }
            Task { await handlePhotoSelection(newValue) }
        }
        .sheet(isPresented: $showingSquareCrop) {
            if let image = imageForCropping {
                SquareCropView(
                    image: image,
                    onCrop: { cropped in
                        croppedImage = cropped
                        showingSquareCrop = false
                        showingDatePicker = true
                    },
                    onCancel: {
                        showingSquareCrop = false
                    }
                )
            }
        }
        .sheet(isPresented: $showingDatePicker) {
            CalendarDatePickerView(
                selectedDate: $selectedDate,
                onConfirm: { date in
                    Task { await addToCalendar(date: date) }
                }
            )
        }
    }
    
    private func handlePhotoSelection(_ item: PhotosPickerItem) async {
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else { return }
            guard let image = UIImage(data: data) else { return }
            
            await MainActor.run {
                imageForCropping = image
                showingSquareCrop = true
            }
        } catch {
            print("❌ Failed to load photo: \(error)")
        }
    }
    
    private func addToCalendar(date: Date) async {
        do {
            print("🗓️ Adding memory to calendar for date: \(date)")
            
            // Upload image to storage and create calendar entry
            if let image = croppedImage {
                // Convert image to data
                guard let imageData = image.jpegData(compressionQuality: 0.8) else {
                    print("❌ Failed to convert image to data")
                    dismiss()
                    return
                }
                
                // Upload to Supabase Storage
                let userId = try await SupabaseService.shared.currentUserId()
                let fileName = "\(userId)/memory_\(UUID().uuidString).jpg"
                
                print("📝 Uploading image: \(fileName)")
                try await SupabaseService.shared.client.storage
                    .from("user-uploads")
                    .upload(fileName, data: imageData, options: FileOptions(contentType: "image/jpeg"))
                
                // Create image data for calendar entry
                let imageMetadata: [String: String] = [
                    "storage_path": fileName,
                    "file_name": fileName.components(separatedBy: "/").last ?? fileName,
                    "file_size": String(imageData.count),
                    "mime_type": "image/jpeg",
                    "width": String(Int(image.size.width)),
                    "height": String(Int(image.size.height))
                ]
                
                // Add to calendar
                try await SupabaseService.shared.addCalendarEntry(
                    imageData: imageMetadata,
                    scheduledDate: date
                )
                
                print("✅ Successfully added memory to calendar for \(date)")
                
                // Store data for widget
                let dateFormatter = DateFormatter()
                dateFormatter.dateStyle = .medium
                let dateString = dateFormatter.string(from: date)
                
                // Get signed URL for widget
                let signedUrl = try await SupabaseService.shared.getSignedImageURL(storagePath: fileName)
                SharedDataManager.shared.storeLatestImageData(
                    imageUrl: signedUrl,
                    partnerName: "You",
                    lastUpdateDate: dateString
                )
            } else {
                print("❌ No image to upload")
            }
            
            // Post notification to refresh calendar
            NotificationCenter.default.post(name: NSNotification.Name("CalendarEntryAdded"), object: nil)
            
            dismiss()
        } catch {
            print("❌ Failed to add to calendar: \(error)")
            dismiss()
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
                Text("Choose Date for Memory")
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
    AddMemoryView()
}
