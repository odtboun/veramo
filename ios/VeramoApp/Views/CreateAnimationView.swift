import SwiftUI
import PhotosUI
import AVFoundation

struct CreateAnimationView: View {
    @State private var infoText: String = ""
    @FocusState private var isFocused: Bool
    
    // Single required reference image
    @State private var referenceItem: PhotosPickerItem? = nil
    @State private var referenceImage: UIImage? = nil
    
    // Fake generation state (no API calls per request)
    @State private var isGenerating: Bool = false
    @State private var previewReady: Bool = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Text("Create Animation")
                        .font(.largeTitle.bold())
                        .foregroundColor(.primary)
                    Text("Generate a short animation using one reference image")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top)
                
                // Information input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Information")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(.gray.opacity(0.2), lineWidth: 1)
                            )
                            .frame(minHeight: 100)
                        if infoText.isEmpty {
                            Text("Describe what you want animated…")
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                        }
                        TextField("", text: $infoText, axis: .vertical)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.clear)
                            .focused($isFocused)
                    }
                }
                
                // Reference image (required)
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text("Reference image (required)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(referenceImage == nil ? "0/1" : "1/1")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    HStack(spacing: 12) {
                        PhotosPicker(selection: $referenceItem, maxSelectionCount: 1, matching: .images) {
                            Image(systemName: "plus")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(width: 36, height: 36)
                                .background(
                                    LinearGradient(colors: [.pink, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .shadow(color: .pink.opacity(0.25), radius: 6, x: 0, y: 4)
                        }
                        if let img = referenceImage {
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: img)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 84, height: 84)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay { RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.2), lineWidth: 1) }
                                Button(action: { removeReference() }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.white)
                                        .shadow(radius: 2)
                                }
                                .padding(4)
                            }
                        }
                    }
                }
                .onChange(of: referenceItem) { _, newItem in
                    guard let item = newItem else { referenceImage = nil; return }
                    Task {
                        if let data = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: data) {
                            await MainActor.run { referenceImage = img }
                        }
                    }
                }
                
                // Generate button (disabled until reference is present)
                Button(action: { generatePreview() }) {
                    HStack {
                        if isGenerating { ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)) }
                        Text(isGenerating ? "Generating…" : "Generate Animation")
                            .font(.headline.bold())
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        LinearGradient(colors: [.pink, .purple], startPoint: .leading, endPoint: .trailing)
                    )
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .pink.opacity(0.2), radius: 8, x: 0, y: 6)
                }
                .buttonStyle(.plain)
                .disabled(referenceImage == nil || isGenerating)
                .opacity((referenceImage == nil || isGenerating) ? 0.6 : 1.0)
                
                // Simple preview placeholder to show flow (no API)
                if previewReady {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                        VStack(spacing: 12) {
                            Image(systemName: "film")
                                .font(.system(size: 40))
                                .foregroundColor(.pink)
                            Text("Preview ready (placeholder)")
                                .font(.headline)
                                .foregroundColor(.primary)
                        }
                        .padding(24)
                    }
                    .aspectRatio(1, contentMode: .fit)
                }
                
                Spacer(minLength: 60)
            }
            .padding()
        }
        .onTapGesture { isFocused = false }
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func removeReference() {
        referenceImage = nil
        referenceItem = nil
    }
    
    private func generatePreview() {
        guard referenceImage != nil else { return }
        isGenerating = true
        previewReady = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isGenerating = false
            previewReady = true
        }
    }
}

#Preview {
    NavigationView { CreateAnimationView() }
}


