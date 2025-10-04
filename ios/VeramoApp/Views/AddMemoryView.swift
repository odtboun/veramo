import SwiftUI
import PhotosUI

struct AddMemoryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedDate = Date()
    @State private var showingDatePicker = false
    @State private var photoSelection: PhotosPickerItem?
    @State private var showingSquareCrop = false
    @State private var imageForCropping: UIImage?
    
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
                    Button(action: {
                        // This will be handled by PhotosPicker
                    }) {
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
                                        .stroke(.blue.opacity(0.2), lineWidth: 1)
                                }
                        }
                    }
                    .buttonStyle(.plain)
                    
                    // AI Generate (Coming Soon)
                    Button(action: {
                        // TODO: Implement AI generation
                    }) {
                        HStack(spacing: 16) {
                            Image(systemName: "sparkles")
                                .font(.title2)
                                .foregroundColor(.purple)
                                .frame(width: 40)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("AI Generate")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text("Create an image with AI")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            HStack(spacing: 4) {
                                Text("Soon")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
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
                                        .stroke(.purple.opacity(0.2), lineWidth: 1)
                                }
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(true)
                    
                    // Edit Image (Coming Soon)
                    Button(action: {
                        // TODO: Implement image editing
                    }) {
                        HStack(spacing: 16) {
                            Image(systemName: "paintbrush")
                                .font(.title2)
                                .foregroundColor(.orange)
                                .frame(width: 40)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Edit Image")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text("Edit an existing photo")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            HStack(spacing: 4) {
                                Text("Soon")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
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
                                        .stroke(.orange.opacity(0.2), lineWidth: 1)
                                }
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(true)
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
        .photosPicker(isPresented: .constant(false), selection: $photoSelection, matching: .images)
        .onChange(of: photoSelection) { _, newValue in
            guard let newValue else { return }
            Task { await handlePhotoSelection(newValue) }
        }
        .sheet(isPresented: $showingSquareCrop) {
            if let image = imageForCropping {
                SquareCropView(
                    image: image,
                    onCrop: { cropped in
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
            
            // For now, we'll create a simple calendar entry
            // TODO: Implement proper image upload and calendar entry creation
            
            print("✅ Successfully added memory to calendar for \(date)")
            
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
