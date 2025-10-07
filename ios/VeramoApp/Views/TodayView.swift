import SwiftUI

struct TodayView: View {
    @State private var todaysImage: String? = nil
    @State private var streakCount = 0
    @State private var hasMemory = false
    @State private var showingAddMemory = false
    @State private var lastStreakCheckDate: String? = nil
    @State private var lastUpdateTimestamp: Date? = nil
    @State private var showingImageFullScreen = false
    @State private var selectedImageUrl: String? = nil
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header with streak
                    VStack(spacing: 16) {
                        
                            // Streak counter with liquid glass
                            HStack {
                                if streakCount > 0 {
                                    Text("💖")
                                        .font(.title2)
                                    Text("\(streakCount) day streak")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                } else {
                                    Text("💖")
                                        .font(.title2)
                                    Text("Start a new streak!")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.secondary)
                                }
                            }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(.ultraThinMaterial)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(.white.opacity(0.2), lineWidth: 1)
                                }
                        }
                    }
                    .padding(.top)
                    
                    // Today's memory
                    VStack(spacing: 16) {
                        Text("Today's Memory")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        if hasMemory, let imageUrl = todaysImage {
                            Button(action: {
                                selectedImageUrl = imageUrl
                                showingImageFullScreen = true
                            }) {
                                AsyncImage(url: URL(string: imageUrl)) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(1, contentMode: .fit)
                                        .clipShape(RoundedRectangle(cornerRadius: 20))
                                } placeholder: {
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(.ultraThinMaterial)
                                        .aspectRatio(1, contentMode: .fit)
                                        .overlay {
                                            ProgressView()
                                                .scaleEffect(1.2)
                                        }
                                }
                                .frame(maxWidth: 300)
                                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                            }
                            .buttonStyle(.plain)
                        } else {
                            // Empty state - Cute and inviting
                            VStack(spacing: 24) {
                                // Cute heart icon with sparkles
                                ZStack {
                                    Circle()
                                        .fill(.pink.opacity(0.1))
                                        .frame(width: 120, height: 120)
                                    
                                    VStack(spacing: 8) {
                                        Image(systemName: "heart.fill")
                                            .font(.system(size: 40))
                                            .foregroundColor(.pink)
                                        
                                        Image(systemName: "sparkles")
                                            .font(.system(size: 16))
                                            .foregroundColor(.yellow)
                                            .offset(x: 20, y: -10)
                                    }
                                }
                                
                                VStack(spacing: 12) {
                                    Text("No Memory Today")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.primary)
                                    
                                    Text("Capture a special moment and create your first memory together! 💕")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                        .lineLimit(3)
                                }
                                
                                // Cute decorative elements
                                HStack(spacing: 8) {
                                    Circle()
                                    .fill(Branding.primaryWarm.opacity(0.3))
                                        .frame(width: 8, height: 8)
                                    Circle()
                                        .fill(.pink.opacity(0.3))
                                        .frame(width: 8, height: 8)
                                    Circle()
                                        .fill(.purple.opacity(0.3))
                                        .frame(width: 8, height: 8)
                                }
                            }
                            .padding(.vertical, 40)
                            .padding(.horizontal, 32)
                            .frame(maxWidth: 320)
                            .background {
                                RoundedRectangle(cornerRadius: 24)
                                    .fill(.ultraThinMaterial)
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 24)
                                            .stroke(
                                                LinearGradient(
                                                    colors: [.pink.opacity(0.3), .blue.opacity(0.3)],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                lineWidth: 1
                                            )
                                    }
                                    .shadow(color: .pink.opacity(0.1), radius: 10, x: 0, y: 5)
                            }
                        }
                    }
                    
                    // Action buttons
                    VStack(spacing: 12) {
                        Button(action: {
                            showingAddMemory = true
                        }) {
                            HStack {
                                Image(systemName: "plus")
                                Text("Add Today's Memory")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Branding.primaryGradient)
                                    .shadow(color: Branding.primaryWarm.opacity(0.3), radius: 8, x: 0, y: 4)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal)
                }
                .padding()
            }
            .navigationBarHidden(true)
                .onAppear {
                    Task { 
                        await loadTodaysMemory()
                        await checkStreakIfNeeded()
                        await checkForNewEntries()
                    }
                }
            .sheet(isPresented: $showingAddMemory) {
                AddMemoryView(subscriptionManager: SubscriptionManager())
            }
            .overlay {
                if showingImageFullScreen, let imageUrl = selectedImageUrl {
                    TodayAnimatedImageView(imageUrl: imageUrl, isPresented: $showingImageFullScreen)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SmartRefreshRequested"))) { _ in
                Task { await checkForNewEntries() }
            }
        }
    }
    
    private func loadTodaysMemory() async {
        do {
            print("🏠 TodayView: Loading today's memory...")
            
            // Priority system for Today view:
            // 1. Partner's upload for today
            // 2. Partner's latest upload (any date)
            // 3. Your latest upload
            // 4. No memory
            
            enum JSONValue: Decodable {
                case string(String)
                case number(Double)
                case bool(Bool)
                case null
                case object([String: JSONValue])
                case array([JSONValue])
                
                init(from decoder: Decoder) throws {
                    let container = try decoder.singleValueContainer()
                    if let string = try? container.decode(String.self) {
                        self = .string(string)
                    } else if let number = try? container.decode(Double.self) {
                        self = .number(number)
                    } else if let bool = try? container.decode(Bool.self) {
                        self = .bool(bool)
                    } else if container.decodeNil() {
                        self = .null
                    } else if let object = try? container.decode([String: JSONValue].self) {
                        self = .object(object)
                    } else if let array = try? container.decode([JSONValue].self) {
                        self = .array(array)
                    } else {
                        throw DecodingError.typeMismatch(JSONValue.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Invalid JSON value"))
                    }
                }
                
                var stringValue: String {
                    switch self {
                    case .string(let value): return value
                    case .number(let value): return String(value)
                    case .bool(let value): return String(value)
                    case .null: return ""
                    case .object(_), .array(_): return ""
                    }
                }
            }
            
            let today = Date()
            let userId = try await SupabaseService.shared.currentUserId()
            print("👤 User ID: \(userId)")
            
            // Format today's date for database queries
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let todayString = dateFormatter.string(from: today)
            
            // Get today's entries - we need to query directly to get proper ordering
            let couple = await SupabaseService.shared.fetchCouple()
            print("💑 Couple: \(couple?.id ?? UUID())")
            
            if let couple = couple {
                // Get today's entries sorted by creation time (most recent first)
                struct CalendarEntryRow: Decodable {
                    let id: UUID
                    let image_data: JSONValue
                    let created_by_user_id: UUID
                    let date: String
                    let created_at: String
                }
                
                let todaysEntries: [CalendarEntryRow] = try await SupabaseService.shared.client
                    .from("calendar_entries")
                    .select("id, image_data, created_by_user_id, date, created_at")
                    .eq("couple_id", value: couple.id)
                    .eq("date", value: todayString)
                    .order("created_at", ascending: false)
                    .execute().value
                
                let partnerTodaysEntries = todaysEntries.filter { $0.created_by_user_id != userId }
                print("📅 Today's entries: \(todaysEntries.count), Partner entries: \(partnerTodaysEntries.count)")
                
                if let partnerTodayEntry = partnerTodaysEntries.first {
                    // Priority 1: Partner's most recent upload for today
                    print("🎯 Found partner's today entry: \(partnerTodayEntry.image_data)")
                    
                    // Convert image_data to [String: String] format
                    let imageData: [String: String]
                    switch partnerTodayEntry.image_data {
                    case .object(let dict):
                        imageData = dict.mapValues { $0.stringValue }
                    default:
                        imageData = [:]
                    }
                    
                    if let storagePath = imageData["storage_path"] {
                        let imageUrl = try await SupabaseService.shared.getSignedImageURL(storagePath: storagePath)
                        print("✅ Partner's today image URL: \(imageUrl)")
                        await MainActor.run {
                            self.todaysImage = imageUrl
                            self.hasMemory = true
                        }
                        
                        // Store data for widget
                        let dateFormatter = DateFormatter()
                        dateFormatter.dateStyle = .medium
                        let todayString = dateFormatter.string(from: Date())
                        SharedDataManager.shared.storeLatestImageData(
                            imageUrl: imageUrl,
                            partnerName: "Partner",
                            lastUpdateDate: todayString
                        )
                        return
                    }
                }
                
                // Priority 2: Your most recent upload for today
                let myTodaysEntries = todaysEntries.filter { $0.created_by_user_id == userId }
                if let myTodayEntry = myTodaysEntries.first {
                    print("🎯 Found my today entry: \(myTodayEntry.image_data)")
                    
                    // Convert image_data to [String: String] format
                    let imageData: [String: String]
                    switch myTodayEntry.image_data {
                    case .object(let dict):
                        imageData = dict.mapValues { $0.stringValue }
                    default:
                        imageData = [:]
                    }
                    
                    if let storagePath = imageData["storage_path"] {
                        let imageUrl = try await SupabaseService.shared.getSignedImageURL(storagePath: storagePath)
                        print("✅ My today image URL: \(imageUrl)")
                        await MainActor.run {
                            self.todaysImage = imageUrl
                            self.hasMemory = true
                        }
                        
                        // Store data for widget
                        print("📱 TodayView: About to store widget data for MY today image")
                        let dateFormatter = DateFormatter()
                        dateFormatter.dateStyle = .medium
                        let todayString = dateFormatter.string(from: Date())
                        SharedDataManager.shared.storeLatestImageData(
                            imageUrl: imageUrl,
                            partnerName: "You",
                            lastUpdateDate: todayString
                        )
                        print("📱 TodayView: Finished storing widget data for MY today image")
                        return
                    }
                }
            }
            
            // Priority 3: Partner's latest upload (any date, today or earlier)
            if let couple = couple {
                // Get all partner entries from today or earlier, sorted by creation time
                struct CalendarEntryRow: Decodable {
                    let id: UUID
                    let image_data: JSONValue
                    let created_by_user_id: UUID
                    let date: String
                    let created_at: String
                }
                
                let allEntries: [CalendarEntryRow] = try await SupabaseService.shared.client
                    .from("calendar_entries")
                    .select("id, image_data, created_by_user_id, date, created_at")
                    .eq("couple_id", value: couple.id)
                    .neq("created_by_user_id", value: userId)
                    .lte("date", value: todayString)
                    .order("created_at", ascending: false)
                    .execute().value
                
                print("📊 Partner entries found: \(allEntries.count)")
                if let latestPartnerEntry = allEntries.first {
                    print("🎯 Latest partner entry: \(latestPartnerEntry.image_data)")
                    
                    // Convert image_data to [String: String] format
                    let imageData: [String: String]
                    switch latestPartnerEntry.image_data {
                    case .object(let dict):
                        imageData = dict.mapValues { $0.stringValue }
                    default:
                        imageData = [:]
                    }
                    
                    if let path = imageData["storage_path"] {
                        let imageUrl = try await SupabaseService.shared.getSignedImageURL(storagePath: path)
                        print("✅ Partner's latest image URL: \(imageUrl)")
                        await MainActor.run {
                            self.todaysImage = imageUrl
                            self.hasMemory = true
                        }
                        
                        // Store data for widget
                        let dateFormatter = DateFormatter()
                        dateFormatter.dateStyle = .medium
                        let todayString = dateFormatter.string(from: Date())
                        SharedDataManager.shared.storeLatestImageData(
                            imageUrl: imageUrl,
                            partnerName: "Partner",
                            lastUpdateDate: todayString
                        )
                        return
                    }
                }
            }
            
            // Priority 4: Your latest upload (any date, today or earlier)
            if let couple = couple {
                struct CalendarEntryRow: Decodable {
                    let id: UUID
                    let image_data: JSONValue
                    let created_by_user_id: UUID
                    let date: String
                    let created_at: String
                }
                
                let myEntries: [CalendarEntryRow] = try await SupabaseService.shared.client
                    .from("calendar_entries")
                    .select("id, image_data, created_by_user_id, date, created_at")
                    .eq("couple_id", value: couple.id)
                    .eq("created_by_user_id", value: userId)
                    .lte("date", value: todayString)
                    .order("created_at", ascending: false)
                    .execute().value
                
                print("📊 My entries found: \(myEntries.count)")
                if let myLatestEntry = myEntries.first {
                    print("🎯 My latest entry: \(myLatestEntry.image_data)")
                    
                    // Convert image_data to [String: String] format
                    let imageData: [String: String]
                    switch myLatestEntry.image_data {
                    case .object(let dict):
                        imageData = dict.mapValues { $0.stringValue }
                    default:
                        imageData = [:]
                    }
                    
                    if let path = imageData["storage_path"] {
                        let imageUrl = try await SupabaseService.shared.getSignedImageURL(storagePath: path)
                        print("✅ My latest image URL: \(imageUrl)")
                        await MainActor.run {
                            self.todaysImage = imageUrl
                            self.hasMemory = true
                        }
                        
                        // Store data for widget
                        let dateFormatter = DateFormatter()
                        dateFormatter.dateStyle = .medium
                        let todayString = dateFormatter.string(from: Date())
                        SharedDataManager.shared.storeLatestImageData(
                            imageUrl: imageUrl,
                            partnerName: "You",
                            lastUpdateDate: todayString
                        )
                        return
                    }
                }
            }
            
            // Priority 4: No memory
            print("❌ No memory found - showing empty state")
            await MainActor.run {
                self.hasMemory = false
                self.todaysImage = nil
            }
            
        } catch {
            print("❌ Failed to load today's memory: \(error)")
            await MainActor.run {
                self.hasMemory = false
                self.todaysImage = nil
            }
        }
    }
    
    private func checkStreakIfNeeded() async {
        let today = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let todayString = dateFormatter.string(from: today)
        
        // Check if we already calculated streak today
        if lastStreakCheckDate == todayString {
            print("🔥 Streak already checked today, skipping...")
            return
        }
        
        print("🔥 Calculating streak for \(todayString)...")
        await calculateStreak()
        
        // Mark that we checked today
        await MainActor.run {
            self.lastStreakCheckDate = todayString
        }
    }
    
    private func calculateStreak() async {
        do {
            let userId = try await SupabaseService.shared.currentUserId()
            let couple = await SupabaseService.shared.fetchCouple()
            
            guard let couple = couple else {
                print("❌ No couple found for streak calculation")
                await MainActor.run { self.streakCount = 0 }
                return
            }
            
            // Get partner's user ID
            let partnerId = couple.user1_id == userId ? couple.user2_id : couple.user1_id
            
            var streak = 0
            let calendar = Calendar.current
            let currentDate = Date()
            
            // Check up to 365 days back (reasonable limit)
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            
            for dayOffset in 0..<365 {
                let checkDate = calendar.date(byAdding: .day, value: -dayOffset, to: currentDate) ?? currentDate
                let formattedDate = dateFormatter.string(from: checkDate)
                
                // Check if both users uploaded on this date
                let bothUploaded = try await checkBothUsersUploaded(
                    coupleId: couple.id,
                    userId: userId,
                    partnerId: partnerId,
                    date: formattedDate
                )
                
                if bothUploaded {
                    streak += 1
                    print("✅ Day \(dayOffset): Both uploaded on \(formattedDate) - Streak: \(streak)")
                } else {
                    print("❌ Day \(dayOffset): Not both uploaded on \(formattedDate) - Streak ends at \(streak)")
                    break
                }
            }
            
            print("🔥 Final streak: \(streak) days")
            await MainActor.run {
                self.streakCount = streak
            }
            
        } catch {
            print("❌ Failed to calculate streak: \(error)")
            await MainActor.run { self.streakCount = 0 }
        }
    }
    
    private func checkBothUsersUploaded(coupleId: UUID, userId: UUID, partnerId: UUID, date: String) async throws -> Bool {
        struct CalendarEntryRow: Decodable {
            let created_by_user_id: UUID
        }
        
        // Get all entries for this couple on this date
        let entries: [CalendarEntryRow] = try await SupabaseService.shared.client
            .from("calendar_entries")
            .select("created_by_user_id")
            .eq("couple_id", value: coupleId)
            .eq("date", value: date)
            .execute().value
        
        // Check if both users have entries
        let userIds = Set(entries.map { $0.created_by_user_id })
        let bothUploaded = userIds.contains(userId) && userIds.contains(partnerId)
        
        print("📊 Date \(date): \(entries.count) entries, User IDs: \(userIds), Both uploaded: \(bothUploaded)")
        return bothUploaded
    }
    
    private func checkForNewEntries() async {
        do {
            let couple = await SupabaseService.shared.fetchCouple()
            guard let couple = couple else { return }
            
            // Define JSONValue and CalendarEntryRow for this function
            enum JSONValue: Decodable {
                case string(String)
                case number(Double)
                case object([String: JSONValue])
                case array([JSONValue])
                case bool(Bool)
                case null
                
                init(from decoder: Decoder) throws {
                    let container = try decoder.singleValueContainer()
                    if container.decodeNil() {
                        self = .null
                    } else if let string = try? container.decode(String.self) {
                        self = .string(string)
                    } else if let number = try? container.decode(Double.self) {
                        self = .number(number)
                    } else if let bool = try? container.decode(Bool.self) {
                        self = .bool(bool)
                    } else if let array = try? container.decode([JSONValue].self) {
                        self = .array(array)
                    } else if let object = try? container.decode([String: JSONValue].self) {
                        self = .object(object)
                    } else {
                        throw DecodingError.typeMismatch(JSONValue.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Invalid JSON value"))
                    }
                }
            }
            
            struct CalendarEntryRow: Decodable {
                let id: UUID
                let date: String
                let created_at: String
                let image_data: JSONValue
                let created_by_user_id: UUID
            }
            
            // Query for entries newer than our last update timestamp
            let query = SupabaseService.shared.client
                .from("calendar_entries")
                .select("id, date, created_at, image_data, created_by_user_id")
                .eq("couple_id", value: couple.id)
                .order("created_at", ascending: false)
            
            // For now, just get the latest entries and let the app handle deduplication
            // TODO: Add proper timestamp filtering when Supabase client supports it
            
            let response: [CalendarEntryRow] = try await query.execute().value
            
            if !response.isEmpty {
                print("🔄 TodayView: Found \(response.count) new entries since last update")
                
                // Update timestamp to the latest entry
                if let latestEntry = response.first {
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'"
                    if let date = dateFormatter.date(from: latestEntry.created_at) {
                        await MainActor.run {
                            self.lastUpdateTimestamp = date
                        }
                    }
                }
                
                // Reload today's memory to show new entries
                await loadTodaysMemory()
            }
        } catch {
            print("❌ TodayView: Failed to check for new entries: \(error)")
        }
    }
}

struct TodayAnimatedImageView: View {
    let imageUrl: String
    @Binding var isPresented: Bool
    @State private var scale: CGFloat = 0.1
    @State private var opacity: Double = 0
    
    var body: some View {
        ZStack {
            // Blurred background
            Color.black.opacity(0.8)
                .ignoresSafeArea()
                .blur(radius: 20)
                .opacity(opacity)
            
            // Image content
            VStack {
                Spacer()
                
                AsyncImage(url: URL(string: imageUrl)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
                        .scaleEffect(scale)
                        .opacity(opacity)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                        .aspectRatio(1, contentMode: .fit)
                        .overlay {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(1.5)
                        }
                        .scaleEffect(scale)
                        .opacity(opacity)
                }
                
                Spacer()
                
                // Close button
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        scale = 0.1
                        opacity = 0
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        isPresented = false
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.white)
                        .background(Color.black.opacity(0.5), in: Circle())
                }
                .padding(.bottom, 50)
                .opacity(opacity)
            }
        }
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.3)) {
                scale = 0.1
                opacity = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isPresented = false
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) {
                scale = 1.0
                opacity = 1.0
            }
        }
    }
}

#Preview {
    TodayView()
}
