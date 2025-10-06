import SwiftUI
import Observation

struct MainTabView: View {
    @State private var selectedTab = 0
    @Bindable var authVM: AuthViewModel
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Home / Today View
            TodayView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Today")
                }
                .tag(0)
            
            // Create (AI Image Generation)
            CreateTabView()
                .tabItem {
                    Image(systemName: "sparkles")
                    Text("Create")
                }
                .tag(1)

            // Shared Calendar
            CalendarView()
                .tabItem {
                    Image(systemName: "calendar")
                    Text("Calendar")
                }
                .tag(2)
            
            // Settings
            SettingsView(authVM: authVM)
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text("Settings")
                }
                .tag(3)
        }
        .accentColor(.primary)
        .onAppear {
            // Notify widget to update when app opens
            NotificationCenter.default.post(name: NSNotification.Name("AppOpened"), object: nil)
        }
        .onChange(of: selectedTab) { _, newTab in
            // Trigger smart refresh when switching to Calendar or Today tabs
            if newTab == 0 || newTab == 1 {
                // Post notification to trigger smart refresh
                NotificationCenter.default.post(name: NSNotification.Name("SmartRefreshRequested"), object: nil)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToCreateTab"))) { _ in
            selectedTab = 1
        }
    }
}

#Preview {
    MainTabView(authVM: AuthViewModel())
}

// MARK: - Create Tab Views

import PhotosUI
import Supabase

struct CreateTabView: View {
    private let columns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]
    @State private var navigateToEditor: Bool = false
    @State private var selectedStyle: String? = nil
    
    private var featuredCardHeight: CGFloat { 180 }
    
    private let featuredTitle = "Create from Scratch"
    
    private let cards: [(title: String, cover: String)] = [
        ("4-panel comic", "https://picsum.photos/seed/comic/800/800"),
        ("Trading card", "https://picsum.photos/seed/card/800/800"),
        ("Dream trip locations", "https://picsum.photos/seed/trip/800/800"),
        ("Anime style", "https://picsum.photos/seed/anime/800/800"),
        ("Oil painting", "https://picsum.photos/seed/oil/800/800"),
        ("Watercolor", "https://picsum.photos/seed/water/800/800"),
        ("Pixel art", "https://picsum.photos/seed/pixel/800/800"),
        ("Cyberpunk neon", "https://picsum.photos/seed/neon/800/800"),
        ("Baroque oil", "https://picsum.photos/seed/baroque/800/800"),
        ("Cartoon", "https://picsum.photos/seed/cartoon/800/800"),
        ("Vaporwave 90s", "https://picsum.photos/seed/vapor/800/800"),
        ("Pop surrealism", "https://picsum.photos/seed/surreal/800/800"),
        ("Origami", "https://picsum.photos/seed/origami/800/800"),
        ("Psychedelic", "https://picsum.photos/seed/psy/800/800"),
        ("Manga", "https://picsum.photos/seed/manga/800/800"),
        ("Risograph", "https://picsum.photos/seed/riso/800/800"),
        ("Abstract", "https://picsum.photos/seed/abstract/800/800"),
        ("Cubism", "https://picsum.photos/seed/cubism/800/800"),
        ("Impressionism", "https://picsum.photos/seed/impress/800/800"),
        ("Surrealism", "https://picsum.photos/seed/surreal2/800/800"),
        ("Futuristic", "https://picsum.photos/seed/future/800/800"),
        ("Silhouette photo", "https://picsum.photos/seed/sil/800/800"),
        ("Studio lighting", "https://picsum.photos/seed/studio/800/800"),
        ("B&W photo", "https://picsum.photos/seed/bw/800/800"),
        ("Bird's-eye view", "https://picsum.photos/seed/birds/800/800"),
        ("Worm's-eye view", "https://picsum.photos/seed/worm/800/800"),
        ("Dutch angle", "https://picsum.photos/seed/dutch/800/800"),
        ("Long exposure", "https://picsum.photos/seed/long/800/800"),
        ("Kinetic art", "https://picsum.photos/seed/kinetic/800/800"),
        ("ASCII art", "https://picsum.photos/seed/ascii/800/800"),
        ("Minimalist line art", "https://picsum.photos/seed/line/800/800"),
        ("Fantasy storybook", "https://picsum.photos/seed/fantasy/800/800"),
        ("Classic comic", "https://picsum.photos/seed/comic2/800/800"),
        ("Retro pixels", "https://picsum.photos/seed/retro/800/800"),
        ("Glitch art", "https://picsum.photos/seed/glitch/800/800"),
        ("Art deco", "https://picsum.photos/seed/deco/800/800"),
        ("Pop art", "https://picsum.photos/seed/pop/800/800"),
        ("1950s pop", "https://picsum.photos/seed/pop50/800/800"),
        ("80s synthwave", "https://picsum.photos/seed/synth/800/800"),
        ("Portrait sketch", "https://picsum.photos/seed/sketch/800/800"),
        ("Digital 3D render", "https://picsum.photos/seed/render/800/800"),
        ("Pastel drawing", "https://picsum.photos/seed/pastel/800/800"),
        ("Ink wash", "https://picsum.photos/seed/ink/800/800")
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Featured full-width card
                    Button {
                        selectedStyle = nil
                        navigateToEditor = true
                    } label: {
                        ZStack(alignment: .bottomLeading) {
                            AsyncImage(url: URL(string: "https://picsum.photos/seed/custom/1200/1200")) { phase in
                                switch phase {
                                case .empty:
                                    Color.gray.opacity(0.1)
                                case .success(let img):
                                    img
                                        .resizable()
                                        .scaledToFill()
                                case .failure:
                                    Color.gray.opacity(0.2)
                                @unknown default:
                                    Color.gray.opacity(0.2)
                                }
                            }
                            .frame(height: featuredCardHeight)
                            .clipped()
                            .overlay {
                                // Subtle glass
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(.ultraThinMaterial)
                                    .opacity(0.15)
                            }
                            .overlay {
                                // Stronger bottom gradient for title readability
                                LinearGradient(
                                    colors: [Color.black.opacity(0.65), Color.black.opacity(0.0)],
                                    startPoint: .bottom,
                                    endPoint: .top
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                            }
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text(featuredTitle)
                                    .font(.title2).bold()
                                    .foregroundColor(.white)
                                Text("Start with your own idea")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.9))
                            }
                            .padding(16)
                        }
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .overlay {
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(.white.opacity(0.25), lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                    
                    // Grid of style cards
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(cards, id: \.title) { item in
                            Button {
                                selectedStyle = item.title
                                navigateToEditor = true
                            } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    ZStack(alignment: .bottomLeading) {
                                        AsyncImage(url: URL(string: item.cover)) { phase in
                                            switch phase {
                                            case .empty:
                                                Color.gray.opacity(0.1)
                                            case .success(let img):
                                                img
                                                    .resizable()
                                                    .scaledToFill()
                                            case .failure:
                                                Color.gray.opacity(0.2)
                                            @unknown default:
                                                Color.gray.opacity(0.2)
                                            }
                                        }
                                        .frame(height: 160)
                                        .clipped()
                                        .overlay {
                                            // Stronger bottom gradient for title readability
                                            LinearGradient(
                                                colors: [Color.black.opacity(0.0), Color.black.opacity(0.55)],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        }
                                        
                                        Text(item.title)
                                            .font(.headline)
                                            .foregroundColor(.white)
                                            .padding(10)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(.white.opacity(0.25), lineWidth: 1)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(16)
            }
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $navigateToEditor) {
                CreateEditorView(preselectedStyle: selectedStyle)
            }
        }
    }
}

struct CreateEditorView: View {
    let preselectedStyle: String?
    @State private var promptText: String = ""
    @State private var referenceItems: [PhotosPickerItem] = []
    @State private var referenceImages: [UIImage] = []
    @State private var isGenerating: Bool = false
    @State private var resultImageURL: URL? = nil
    @State private var showingDatePicker: Bool = false
    @State private var isManuallyRemoving: Bool = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Style info
                if let style = preselectedStyle {
                    HStack {
                        Text(style)
                            .font(.headline)
                        Spacer()
                        Text("Preset")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(12)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay { RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.2), lineWidth: 1) }
                }
                
                // Prompt input
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Describe your image")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        if preselectedStyle != nil {
                            Text("Optional")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.leading, 6)
                        }
                    }
                    TextField("A cozy cabin under the northern lights...", text: $promptText, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                }
                
                // Reference images
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text("Reference images (optional)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        Spacer()
                        Text("\(referenceImages.count)/5")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    PhotosPicker(selection: $referenceItems, maxSelectionCount: 5, matching: .images) {
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
                    
                    if !referenceImages.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(Array(referenceImages.enumerated()), id: \.offset) { idx, img in
                                    ZStack(alignment: .topTrailing) {
                                        Image(uiImage: img)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 84, height: 84)
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                            .overlay { RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.2), lineWidth: 1) }
                                        Button(action: { removeReference(at: idx) }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.white)
                                                .shadow(radius: 2)
                                        }
                                        .padding(4)
                                    }
                                }
                            }
                            .padding(.top, 4)
                        }
                    }
                }
                .onChange(of: referenceItems) { _, newItems in
                    // Skip if we're manually removing items to avoid flash
                    guard !isManuallyRemoving else { return }
                    
                    Task {
                        // Clear existing images and replace with new selection
                        await MainActor.run {
                            referenceImages.removeAll()
                        }
                        
                        // Process new items (up to 5)
                        for item in newItems.prefix(5) {
                            if let data = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: data) {
                                await MainActor.run {
                                    if referenceImages.count < 5 { referenceImages.append(img) }
                                }
                            }
                        }
                    }
                }
                
                // Generate button
                Button {
                    generatePlaceholder()
                } label: {
                    HStack {
                        if isGenerating { ProgressView().tint(.white) }
                        Text(isGenerating ? "Generating..." : "Generate")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(colors: [.pink, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: .pink.opacity(0.3), radius: 8, x: 0, y: 6)
                }
                .buttonStyle(.plain)
                .disabled(isGenerating)
                
                // Result
                if let url = resultImageURL {
                    VStack(spacing: 12) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .empty:
                                ZStack { Color.gray.opacity(0.1); ProgressView() }
                            case .success(let img):
                                img.resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 16))
                            case .failure:
                                Color.gray.opacity(0.2)
                            @unknown default:
                                Color.gray.opacity(0.2)
                            }
                        }
                        .aspectRatio(1, contentMode: .fit)
                        
                        HStack(spacing: 12) {
                            // Secondary actions
                            Button { saveToPhotos() } label: { labelCapsule(title: "Save", system: "square.and.arrow.down") }
                            Button { referenceFromResult(url: url) } label: { labelCapsule(title: "Edit", system: "pencil") }
                            
                            // Emphasized primary action on the right
                            Button { showingDatePicker = true } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "calendar")
                                    Text("Add to calendar")
                                        .fontWeight(.semibold)
                                }
                                .padding(.vertical, 10)
                                .padding(.horizontal, 14)
                                .background(LinearGradient(colors: [.pink, .orange], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .foregroundColor(.white)
                                .clipShape(Capsule())
                                .shadow(color: .pink.opacity(0.3), radius: 6, x: 0, y: 4)
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showingDatePicker) {
            CalendarDatePickerView(
                selectedDate: .constant(Date()),
                onConfirm: { date in
                    Task { await addResultToCalendar(date: date) }
                }
            )
        }
    }
    
    private func labelCapsule(title: String, system: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: system)
            Text(title)
        }
        .font(.subheadline)
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(LinearGradient(colors: [.blue.opacity(0.15), .purple.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing))
        .clipShape(Capsule())
        .overlay { Capsule().stroke(.blue.opacity(0.3), lineWidth: 1) }
    }
    
    private func generatePlaceholder() {
        isGenerating = true
        resultImageURL = nil
        
        Task {
            do {
                let generatedImage = try await ImageGenerationService.shared.generateImage(
                    description: promptText.isEmpty ? "A beautiful landscape" : promptText,
                    styleLabel: preselectedStyle,
                    referenceImages: referenceImages
                )
                
                // Save the generated image to a temporary file
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("generated_\(UUID().uuidString).png")
                
                if let imageData = generatedImage.pngData() {
                    try imageData.write(to: tempURL)
                    
                    await MainActor.run {
                        resultImageURL = tempURL
                        isGenerating = false
                    }
                } else {
                    await MainActor.run {
                        isGenerating = false
                    }
                }
                
            } catch {
                print("❌ Image generation failed: \(error)")
                
                // Fallback to a placeholder on error
                let seed = Int.random(in: 1...10_000)
                let fallbackURL = URL(string: "https://picsum.photos/seed/\(seed)/1024/1024")!
                
                await MainActor.run {
                    resultImageURL = fallbackURL
                    isGenerating = false
                }
            }
        }
    }
    
    private func saveToPhotos() {
        guard let url = resultImageURL else { return }
        
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let image = UIImage(data: data) {
                    await MainActor.run {
                        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                        print("✅ Image saved to Photos")
                    }
                }
            } catch {
                print("❌ Failed to save image: \(error)")
            }
        }
    }
    
    private func referenceFromResult(url: URL) {
        // First tap: clear references
        referenceImages.removeAll()
        referenceItems.removeAll()
        
        // Second tap: add result as reference
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            Task {
                do {
                    let (data, _) = try await URLSession.shared.data(from: url)
                    if let img = UIImage(data: data) {
                        await MainActor.run {
                            referenceImages.append(img)
                        }
                    }
                } catch {
                    print("Failed to load result for reference: \(error)")
                }
            }
        }
    }
    
    private func removeReference(at index: Int) {
        guard referenceImages.indices.contains(index) else { return }
        
        // Set flag to prevent onChange from clearing all images
        isManuallyRemoving = true
        
        referenceImages.remove(at: index)
        if referenceItems.indices.contains(index) {
            referenceItems.remove(at: index)
        }
        
        // Reset flag after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isManuallyRemoving = false
        }
    }
    
    private func addResultToCalendar(date: Date) async {
        defer { showingDatePicker = false }
        guard let url = resultImageURL else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let image = UIImage(data: data), let imageData = image.jpegData(compressionQuality: 0.9) else { return }
            
            let userId = try await SupabaseService.shared.currentUserId()
            let fileName = "\(userId)/generated_\(UUID().uuidString).jpg"
            
            try await SupabaseService.shared.client.storage
                .from("user-uploads")
                .upload(fileName, data: imageData, options: FileOptions(contentType: "image/jpeg"))
            
            let imageMetadata: [String: String] = [
                "storage_path": fileName,
                "file_name": fileName.components(separatedBy: "/").last ?? fileName,
                "file_size": String(imageData.count),
                "mime_type": "image/jpeg",
                "width": String(Int(image.size.width)),
                "height": String(Int(image.size.height))
            ]
            
            try await SupabaseService.shared.addCalendarEntry(
                imageData: imageMetadata,
                scheduledDate: date
            )
            
            NotificationCenter.default.post(name: NSNotification.Name("CalendarEntryAdded"), object: nil)
        } catch {
            print("❌ addResultToCalendar error: \(error)")
        }
    }
}
