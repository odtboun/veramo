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
import AVFoundation

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

// MARK: - Streak Views (inlined to ensure build without project file edits)

struct StreakMilestone: Identifiable {
    let id = UUID()
    let day: Int
    let title: String
    let description: String
    let requirementText: String
    let isUnlocked: Bool
}

struct StreakProgressView: View {
    @State private var currentStreak: Int = 0
    @State private var navigateToAnimation: Bool = false
    @State private var showCouplePodcast: Bool = false
    
    private let milestones: [StreakMilestone] = [
        StreakMilestone(day: 0, title: "Generate Images in Any Style", description: "Create beautiful AI-generated images with any style you choose", requirementText: "Available Now", isUnlocked: true),
        StreakMilestone(day: 7, title: "Couple Podcast", description: "An audio podcast discussing your relationship", requirementText: "7+ day streak", isUnlocked: true),
        StreakMilestone(day: 30, title: "Monthly Summary", description: "AI-generated monthly relationship insights and highlights", requirementText: "30+ day streak", isUnlocked: false),
        StreakMilestone(day: 60, title: "Short Animation", description: "Personalized animations celebrating your milestones", requirementText: "60+ day streak", isUnlocked: true),
        StreakMilestone(day: 90, title: "Short Video", description: "A video podcast discussing your relationship", requirementText: "90+ day streak", isUnlocked: false),
        StreakMilestone(day: 180, title: "Longer Animation", description: "Extended personalized animations celebrating your milestones", requirementText: "180+ day streak", isUnlocked: false),
        StreakMilestone(day: 365, title: "Longer Video", description: "Extended video podcast discussing your relationship", requirementText: "365+ day streak", isUnlocked: false)
    ]
    
    private var mascotImageName: String {
        if currentStreak < 3 {
            return "lessthan_3day"
        } else if currentStreak < 7 {
            return "lessthan_7day"
        } else if currentStreak < 14 {
            return "lessthan_14day"
        } else if currentStreak < 30 {
            return "lessthan_30day"
        } else {
            return "morethan_30day"
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Spacer().frame(height: 20)
                    
                    // Mascot image based on streak
                    Image(mascotImageName)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 240)
                        .padding(.horizontal)
                    
                    VStack(spacing: 4) {
                        Text("\(currentStreak)")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                        Text("Days Streak")
                            .font(.subheadline)
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(
                        LinearGradient(colors: [Color(red: 0.92, green: 0.85, blue: 0.33), Color(red: 0.81, green: 0.24, blue: 0.08)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .padding(.horizontal)
                    
                    Text("Increase your streak to unlock special features")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    
                    LazyVStack(spacing: 16) {
                        ForEach(milestones) { m in
                            Button {
                                if m.title == "Short Animation" && m.isUnlocked {
                                    navigateToAnimation = true
                                } else if m.title == "Generate Images in Any Style" && m.isUnlocked {
                                    NotificationCenter.default.post(name: NSNotification.Name("NavigateToCreateTab"), object: nil)
                                } else if m.title == "Couple Podcast" && m.isUnlocked {
                                    showCouplePodcast = true
                                }
                            } label: {
                                HStack(alignment: .top, spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(m.isUnlocked ? Color.green.opacity(0.1) : Color.gray.opacity(0.1))
                                            .frame(width: 40, height: 40)
                                        Image(systemName: m.isUnlocked ? "checkmark" : "lock.fill")
                                            .foregroundColor(m.isUnlocked ? .green : Color(red: 0.90, green: 0.59, blue: 0.17))
                                            .font(.system(size: 16, weight: .semibold))
                                    }
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(m.title)
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        Text(m.description)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                        Text(m.requirementText)
                                            .font(.footnote.weight(.semibold))
                                            .foregroundColor(Color(red: 0.90, green: 0.59, blue: 0.17))
                                    }
                                    Spacer()
                                }
                                .padding(16)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(m.isUnlocked ? Color.green.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 1.5)
                                )
                                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
                            }
                            .buttonStyle(.plain)
                            .disabled(!m.isUnlocked)
                            .padding(.horizontal)
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
            .background(Color.white)
            .navigationDestination(isPresented: $navigateToAnimation) {
                CreateAnimationView()
            }
            .navigationDestination(isPresented: $showCouplePodcast) {
                CouplePodcastView()
            }
        }
        .preferredColorScheme(.light)
    }
}

struct CreateAnimationView: View {
    @State private var infoText: String = ""
    @FocusState private var isFocused: Bool
    @State private var referenceItems: [PhotosPickerItem] = []
    @State private var referenceImage: UIImage? = nil
    @State private var isGenerating: Bool = false
    @State private var previewReady: Bool = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("Create Animation")
                        .font(.largeTitle.bold())
                    Text("Generate a short animation using one reference image")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Information")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(.gray.opacity(0.2), lineWidth: 1))
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
                        PhotosPicker(selection: $referenceItems, maxSelectionCount: 1, matching: .images) {
                            Image(systemName: "plus")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(width: 36, height: 36)
                                .background(LinearGradient(colors: [.pink, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        if let img = referenceImage {
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: img)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 84, height: 84)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                Button(action: { referenceImage = nil; referenceItems = [] }) {
                                    Image(systemName: "xmark.circle.fill").foregroundColor(.white)
                                }
                                .padding(4)
                            }
                        }
                    }
                }
                .onChange(of: referenceItems) { _, newItems in
                    guard let item = newItems.first else { referenceImage = nil; return }
                    Task {
                        if let data = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: data) {
                            await MainActor.run { referenceImage = img }
                        }
                    }
                }
                
                Button(action: { generatePreview() }) {
                    HStack {
                        if isGenerating { ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)) }
                        Text(isGenerating ? "Generating…" : "Generate Animation").font(.headline.bold())
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(LinearGradient(colors: [.pink, .purple], startPoint: .leading, endPoint: .trailing))
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
                .disabled(referenceImage == nil || isGenerating)
                .opacity((referenceImage == nil || isGenerating) ? 0.6 : 1.0)
                
                if previewReady {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16).fill(.ultraThinMaterial)
                        VStack(spacing: 12) {
                            Image(systemName: "film").font(.system(size: 40)).foregroundColor(.pink)
                            Text("Preview ready (placeholder)").font(.headline)
                        }.padding(24)
                    }
                    .aspectRatio(1, contentMode: .fit)
                }
                
                Spacer(minLength: 60)
            }
            .padding()
        }
        .onTapGesture { isFocused = false }
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

// MARK: - Inlined CouplePodcastView
struct CouplePodcastView: View {
    @State private var informationText: String = ""
    @FocusState private var isFocused: Bool
    @State private var isGenerating: Bool = false
    @State private var resultAudioURL: URL? = nil
    @State private var audioPlayer: AVAudioPlayer? = nil
    @State private var audioPlayerDelegate: AudioPlayerDelegate? = nil
    @State private var isPlaying: Bool = false
    @State private var currentTime: Double = 0
    @State private var duration: Double = 0
    @State private var playbackTimer: Timer? = nil
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("Couple Podcast")
                        .font(.largeTitle.bold())
                    Text("Generate an audio podcast discussing your relationship")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Information")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(.gray.opacity(0.2), lineWidth: 1))
                            .frame(minHeight: 100)
                        if informationText.isEmpty {
                            Text("Tell us about your relationship, special moments, or what you'd like discussed…")
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                        }
                        TextField("", text: $informationText, axis: .vertical)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.clear)
                            .focused($isFocused)
                    }
                }
                
                Button(action: { generatePodcast() }) {
                    HStack {
                        if isGenerating { ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)) }
                        Text(isGenerating ? "Generating…" : "Generate Podcast").font(.headline.bold())
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(informationText.isEmpty ? LinearGradient(colors: [.gray, .gray], startPoint: .topLeading, endPoint: .bottomTrailing) : LinearGradient(colors: [.pink, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(informationText.isEmpty || isGenerating)
                
                if let audioURL = resultAudioURL {
                    AudioPlayerView(
                        audioURL: audioURL,
                        isPlaying: $isPlaying,
                        currentTime: $currentTime,
                        duration: $duration,
                        onPlayPause: { isPlaying ? pauseAudio() : playAudio() },
                        onSeek: { time in seekAudio(to: time) },
                        onDownload: { downloadAudio() },
                        onShare: { shareAudio() }
                    )
                }
                
                Spacer(minLength: 60)
            }
            .padding()
        }
        .onTapGesture { isFocused = false }
        .onDisappear {
            stopAudio()
        }
    }
    
    private func generatePodcast() {
        guard !informationText.isEmpty else { return }
        isGenerating = true
        resultAudioURL = nil
        
        Task {
            do {
                let url = URL(string: "https://veramo-podcast-20729573701.us-east1.run.app/generate-podcast")!
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                
                let payload = ["prompt": informationText]
                request.httpBody = try JSONSerialization.data(withJSONObject: payload)
                
                let (data, _) = try await URLSession.shared.data(for: request)
                let response = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                
                if let audioDict = response?["audio"] as? [String: Any],
                   let audioURLString = audioDict["url"] as? String,
                   let audioURL = URL(string: audioURLString) {
                    
                    // Download the audio file to a temporary location
                    let (audioData, _) = try await URLSession.shared.data(from: audioURL)
                    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("podcast_\(UUID().uuidString).mp3")
                    try audioData.write(to: tempURL)
                    
                    await MainActor.run {
                        self.resultAudioURL = tempURL
                        self.duration = response?["duration"] as? Double ?? 0
                        self.isGenerating = false
                        setupAudioPlayer()
                    }
                } else {
                    await MainActor.run {
                        self.isGenerating = false
                    }
                }
            } catch {
                print("❌ Podcast generation failed: \(error)")
                await MainActor.run {
                    self.isGenerating = false
                }
            }
        }
    }
    
    private func setupAudioPlayer() {
        guard let audioURL = resultAudioURL else { return }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: audioURL)
            audioPlayerDelegate = AudioPlayerDelegate { [self] in
                stopAudio()
            }
            audioPlayer?.delegate = audioPlayerDelegate
            audioPlayer?.prepareToPlay()
            if duration == 0 {
                duration = audioPlayer?.duration ?? 0
            }
        } catch {
            print("❌ Failed to setup audio player: \(error)")
        }
    }
    
    private func playAudio() {
        audioPlayer?.play()
        isPlaying = true
        startPlaybackTimer()
    }
    
    private func pauseAudio() {
        audioPlayer?.pause()
        isPlaying = false
        stopPlaybackTimer()
    }
    
    private func stopAudio() {
        audioPlayer?.stop()
        audioPlayer?.currentTime = 0
        isPlaying = false
        currentTime = 0
        stopPlaybackTimer()
    }
    
    private func seekAudio(to time: Double) {
        audioPlayer?.currentTime = time
        currentTime = time
    }
    
    private func startPlaybackTimer() {
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            currentTime = audioPlayer?.currentTime ?? 0
        }
    }
    
    private func stopPlaybackTimer() {
        playbackTimer?.invalidate()
        playbackTimer = nil
    }
    
    private func downloadAudio() {
        // Placeholder for download functionality
        print("Download audio")
    }
    
    private func shareAudio() {
        // Placeholder for share functionality
        print("Share audio")
    }
}

struct AudioPlayerView: View {
    let audioURL: URL
    @Binding var isPlaying: Bool
    @Binding var currentTime: Double
    @Binding var duration: Double
    let onPlayPause: () -> Void
    let onSeek: (Double) -> Void
    let onDownload: () -> Void
    let onShare: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            // Progress bar
            VStack(spacing: 8) {
                Slider(value: Binding(
                    get: { currentTime },
                    set: { onSeek($0) }
                ), in: 0...max(duration, 1))
                .accentColor(.pink)
                
                HStack {
                    Text(timeString(from: currentTime))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(timeString(from: duration))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Control buttons
            HStack(spacing: 24) {
                Button(action: onShare) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.title2)
                        .foregroundColor(.primary)
                }
                
                Button(action: onDownload) {
                    Image(systemName: "arrow.down.circle")
                        .font(.title2)
                        .foregroundColor(.primary)
                }
                
                Button(action: onPlayPause) {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.pink)
                }
            }
        }
        .padding()
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func timeString(from timeInterval: Double) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

class AudioPlayerDelegate: NSObject, AVAudioPlayerDelegate {
    private let onFinish: () -> Void
    
    init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        onFinish()
    }
}
