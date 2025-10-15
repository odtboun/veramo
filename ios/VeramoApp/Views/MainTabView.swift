import SwiftUI
import Observation
import Adapty
import AdaptyUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @Bindable var authVM: AuthViewModel
    @ObservedObject var subscriptionManager: SubscriptionManager
    
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
            CreateTabView(subscriptionManager: subscriptionManager)
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
            
            // Streak Progress
            StreakProgressView()
                .tabItem {
                    Image(systemName: "flame.fill")
                    Text("Streak")
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
    MainTabView(authVM: AuthViewModel(), subscriptionManager: SubscriptionManager())
}

// MARK: - Create Tab Views

import PhotosUI
import Supabase

struct CreateTabView: View {
    @ObservedObject var subscriptionManager: SubscriptionManager
    private let columns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]
    @State private var navigateToEditor: Bool = false
    @State private var selectedStyle: String? = nil
    
    private var featuredCardHeight: CGFloat { 180 }
    
    private let featuredTitle = "Create from Scratch"
    
    private let cards: [(title: String, coverName: String)] = {
        // Load local covers from bundled folder; map filename to a readable short title
        let base = Bundle.main.bundleURL.appendingPathComponent("style-covers", isDirectory: true)
        let fm = FileManager.default
        let files = (try? fm.contentsOfDirectory(at: base, includingPropertiesForKeys: nil)) ?? []
        let imageFiles = files.filter { ["png", "jpg", "jpeg", "webp"].contains($0.pathExtension.lowercased()) }
        let items: [(String, String)] = imageFiles.map { url in
            let raw = url.deletingPathExtension().lastPathComponent
            let short = raw
                .replacingOccurrences(of: "_", with: " ")
                .replacingOccurrences(of: "-", with: " ")
                .capitalized
            
            // Use asset catalog image for 4-panel comic to match onboarding magic demo
            if raw.lowercased() == "4-panel-comic" {
                return (short, "4-panel-comic")
            }
            
            return (short, "style-covers/" + url.lastPathComponent)
        }
        // Fallback to empty if none found
        return items.sorted { $0.0.localizedCaseInsensitiveCompare($1.0) == .orderedAscending }
    }()
    
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
                            // Static cover image for From Scratch card
                            Image("moss_on_rock")
                                .resizable()
                                .scaledToFill()
                                .frame(height: featuredCardHeight)
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                            .overlay {
                                // Subtle glass
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(.ultraThinMaterial)
                                    .opacity(0.15)
                            }
                            .overlay {
                                // Stronger bottom gradient for title readability over the GIF
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
                                        Image(uiImage: UIImage(named: item.coverName) ?? UIImage())
                                            .resizable()
                                            .aspectRatio(1, contentMode: .fit)
                                            .clipShape(RoundedRectangle(cornerRadius: 16))
                                            .overlay {
                                                // Stronger bottom gradient for title readability
                                                LinearGradient(
                                                    colors: [Color.black.opacity(0.0), Color.black.opacity(0.55)],
                                                    startPoint: .top,
                                                    endPoint: .bottom
                                                )
                                                .clipShape(RoundedRectangle(cornerRadius: 16))
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
                CreateEditorView(preselectedStyle: selectedStyle, subscriptionManager: subscriptionManager)
            }
        }
    }
}

struct CreateEditorView: View {
    let preselectedStyle: String?
    @ObservedObject var subscriptionManager: SubscriptionManager
    @State private var promptText: String = ""
    @State private var referenceItems: [PhotosPickerItem] = []
    @State private var referenceImages: [UIImage] = []
    @State private var isGenerating: Bool = false
    @State private var resultImageURL: URL? = nil
    @State private var showingDatePicker: Bool = false
    @State private var selectedCalendarDate: Date = Date()
    @State private var isManuallyRemoving: Bool = false
    @State private var loadingMessages: [String] = []
    @State private var currentLoadingMessageIndex: Int = 0
    
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
                    Task {
                        let hasAccess = await subscriptionManager.presentPaywallIfNeeded(placementId: "in-app-weekly")
                        if hasAccess {
                            generatePlaceholder()
                        }
                    }
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
                            Button { 
                                Task {
                                    let hasAccess = await subscriptionManager.presentPaywallIfNeeded()
                                    if hasAccess {
                                        showingDatePicker = true
                                    }
                                }
                            } label: {
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
                } else if isGenerating {
                    // Rotating romantic loading messages while waiting for the image URL
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                        VStack(spacing: 14) {
                            ProgressView()
                                .tint(.primary)
                            Text(currentLoadingMessage)
                                .font(.headline)
                                .multilineTextAlignment(.center)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 16)
                        }
                        .padding(24)
                    }
                    .aspectRatio(1, contentMode: .fit)
                }
            }
            .padding(16)
            // Advance message every 2 seconds while generating and no result yet
            .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in
                if isGenerating && resultImageURL == nil && !loadingMessages.isEmpty {
                    currentLoadingMessageIndex = (currentLoadingMessageIndex + 1) % loadingMessages.count
                }
            }
        }
        .navigationBarHidden(true)
                .sheet(isPresented: $showingDatePicker) {
                    CalendarDatePickerView(
                        selectedDate: $selectedCalendarDate,
                        subscriptionManager: subscriptionManager,
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
        // Shuffle messages for this run
        loadingMessages = romanticLoadingMessages.shuffled()
        currentLoadingMessageIndex = 0
        
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

    private var currentLoadingMessage: String {
        guard !loadingMessages.isEmpty else { return "Generating..." }
        return loadingMessages[currentLoadingMessageIndex]
    }

    private var romanticLoadingMessages: [String] {
        [
            "Painting your love story with pixels...",
            "Asking Cupid for art advice...",
            "Mixing digital paint and happy memories...",
            "Dusting off the old AI photo albums...",
            "Teaching our AI about date nights...",
            "Consulting with rom-com experts...",
            "Finding the perfect filter for your affection...",
            "Waiting for the digital paint to dry...",
            "Whispering sweet nothings to the server...",
            "Developing your photo in the darkroom of the future...",
            "Shuffling through a deck of romantic art styles...",
            "Recalling our first date with the AI...",
            "Putting the 'art' in 'heart'...",
            "Brewing a fresh pot of creative juices...",
            "Untangling the red string of fate...",
            "Sending a raven to the art masters for tips...",
            "Composing a sonnet for your picture...",
            "Making sure the AI remembers your anniversary...",
            "Calculating the formula of love...",
            "Reading Mamamoo - I Love Too Lyrics",
            "Choosing the best AI for real lovers",
            "Looking for lost childhood photos",
            "Ordering from Chungking Express",
            "Calling my highschool art teacher"
        ]
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
