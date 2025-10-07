import SwiftUI
import Supabase
import Combine

struct CalendarView: View {
    @State private var selectedDate = Date()
    @State private var currentMonth = Date()
    @State private var calendarEntries: [String: [CalendarEntry]] = [:]
    @State private var hasCouple = false
    @State private var isLoading = false
    @State private var showingAddMemory = false
    @State private var lastCacheMonth: String? = nil
    @State private var lastUpdateTimestamp: Date? = nil
    
    // Static cache shared across all instances
    static var cachedImages: [String: UIImage] = [:]
    
    var body: some View {
        NavigationView {
            if hasCouple {
                // Show calendar when paired
                VStack(spacing: 0) {
                    // Month header
                    HStack {
                        Button(action: previousMonth) {
                            Image(systemName: "chevron.left")
                                .font(.title2)
                                .foregroundStyle(Branding.primaryWarm)
                        }
                        
                        Spacer()
                        
                        Text(currentMonth, formatter: monthFormatter)
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        Button(action: nextMonth) {
                            Image(systemName: "chevron.right")
                                .font(.title2)
                                .foregroundStyle(Branding.primaryWarm)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 16)
                    
                        // Calendar grid
                        ScrollView {
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                                // Day headers
                                ForEach(Array(["S", "M", "T", "W", "T", "F", "S"].enumerated()), id: \.offset) { index, day in
                                    Text(day)
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.secondary)
                                        .frame(height: 30)
                                }

                                // Calendar days
                                ForEach(daysInMonth, id: \.self) { date in
                                    let entriesForDay = calendarEntries[dateKey(for: date)] ?? []
                                    CalendarDayView(
                                        date: date,
                                        isSelected: Calendar.current.isDate(date, inSameDayAs: selectedDate),
                                        entries: entriesForDay,
                                        showGiftForFutureMine: shouldShowGift(for: date, entries: entriesForDay)
                                    ) {
                                        selectedDate = date
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        // Add to Calendar button under grid
                        Button(action: { showingAddMemory = true }) {
                            HStack(spacing: 8) {
                                Image(systemName: "calendar.badge.plus")
                                Text("Add to Calendar")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Branding.primaryGradient)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .padding(.horizontal)
                        }
                    
                    // Selected date details
                    if let entries = calendarEntries[dateKey(for: selectedDate)], !entries.isEmpty {
                        VStack(spacing: 16) {
                            Divider()

                            Text("Memories for \(selectedDate, formatter: dateFormatter)")
                                .font(.headline)
                                .fontWeight(.semibold)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(entries, id: \.id) { entry in
                                        CalendarEntryView(entry: entry)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                        .padding()
                    }
                }
                .navigationBarHidden(true)
                .toolbar {
                    // Removed trailing button; we now show a big CTA under the grid
                }
                .sheet(isPresented: $showingAddMemory) {
                    AddMemoryView(subscriptionManager: SubscriptionManager())
                }
                .onAppear {
                    Task { 
                        await loadCalendarData()
                        await checkForNewEntries()
                    }
                }
                .onChange(of: currentMonth) { _, _ in
                    Task { await loadCalendarData() }
                }
                .refreshable {
                    await loadCalendarData()
                }
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("CalendarEntryAdded"))) { _ in
                    Task { await loadCalendarData() }
                }
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SmartRefreshRequested"))) { _ in
                    Task { await checkForNewEntries() }
                }
            } else {
                // Show gate when not paired
                CalendarAccessGate()
            }
        }
        .task {
            let couple = await SupabaseService.shared.fetchCouple()
            await MainActor.run { self.hasCouple = (couple != nil) }
        }
    }
    
    private var daysInMonth: [Date] {
        let calendar = Calendar.current
        let startOfMonth = calendar.dateInterval(of: .month, for: currentMonth)?.start ?? currentMonth
        let range = calendar.range(of: .day, in: .month, for: currentMonth) ?? 1..<32
        
        return range.compactMap { day in
            calendar.date(byAdding: .day, value: day - 1, to: startOfMonth)
        }
    }
    
    private func previousMonth() {
        currentMonth = Calendar.current.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
    }
    
    private func nextMonth() {
        currentMonth = Calendar.current.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
    }
    
    private func dateKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    private func shouldShowGift(for date: Date, entries: [CalendarEntry]) -> Bool {
        // Only for future dates
        let calendar = Calendar.current
        if calendar.isDateInToday(date) || date < Date() { return false }
        // If there are entries and all are mine (no partner entries), show gift
        guard !entries.isEmpty else { return false }
        return !entries.contains(where: { $0.isFromPartner })
    }
    
        private func loadCalendarData() async {
            await MainActor.run { self.isLoading = true }
            
            do {
                // Check if we need to clear cache for new month
                let currentMonthString = getMonthString(from: currentMonth)
                if lastCacheMonth != nil && lastCacheMonth != currentMonthString {
                    // New month - clear old cache
                    Self.cachedImages = [:]
                }
                await MainActor.run { self.lastCacheMonth = currentMonthString }
                
                // Get all calendar entries for the current month
                let startOfMonth = Calendar.current.dateInterval(of: .month, for: currentMonth)?.start ?? currentMonth
                let endOfMonth = Calendar.current.dateInterval(of: .month, for: currentMonth)?.end ?? currentMonth
                
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                
                let startDate = dateFormatter.string(from: startOfMonth)
                let endDate = dateFormatter.string(from: endOfMonth)
                
                // Get couple info
                guard let couple = await SupabaseService.shared.fetchCouple() else {
                    await MainActor.run { self.isLoading = false }
                    return
                }
                
                // Fetch calendar entries for the month
                    struct CalendarEntryRow: Decodable {
                        let id: UUID
                        let image_data: JSONValue
                        let created_by_user_id: UUID
                        let date: String
                    }
                    
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
                
                let entries: [CalendarEntryRow] = try await SupabaseService.shared.client
                    .from("calendar_entries")
                    .select("id, image_data, created_by_user_id, date")
                    .eq("couple_id", value: couple.id)
                    .gte("date", value: startDate)
                    .lte("date", value: endDate)
                    .execute().value
                
                // Convert to CalendarEntry objects with privacy filtering
                let userId = try await SupabaseService.shared.currentUserId()
                let today = Date()
                let todayString = dateFormatter.string(from: today)
                
                let calendarEntries = entries.compactMap { entry -> CalendarEntry? in
                    // Convert image_data to [String: String] format
                    let imageData: [String: String]
                    switch entry.image_data {
                    case .object(let dict):
                        imageData = dict.mapValues { $0.stringValue }
                    default:
                        imageData = [:]
                    }
                    
                    // Privacy check: Don't show partner's future images
                    let isFromPartner = entry.created_by_user_id != userId
                    let isFutureDate = entry.date > todayString
                    
                    if isFromPartner && isFutureDate {
                        print("🔒 Hiding partner's future image for \(entry.date)")
                        return nil
                    }
                    
                    return CalendarEntry(
                        id: entry.id,
                        imageData: imageData,
                        createdByUserId: entry.created_by_user_id,
                        isFromPartner: isFromPartner,
                        date: entry.date
                    )
                }
                
                // Group entries by date
                var groupedEntries: [String: [CalendarEntry]] = [:]
                for entry in calendarEntries {
                    let key = entry.date
                    if groupedEntries[key] == nil {
                        groupedEntries[key] = []
                    }
                    groupedEntries[key]?.append(entry)
                }
                
                // Pre-cache images for current month
                await preCacheImages(for: calendarEntries)
                
                await MainActor.run {
                    self.calendarEntries = groupedEntries
                    self.isLoading = false
                }
                
            } catch {
                print("❌ Failed to load calendar data: \(error)")
                await MainActor.run { self.isLoading = false }
            }
        }
        
        private func getMonthString(from date: Date) -> String {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM"
            return formatter.string(from: date)
        }
        
        private func preCacheImages(for entries: [CalendarEntry]) async {
            // Use TaskGroup for concurrent image loading
            await withTaskGroup(of: Void.self) { group in
                for entry in entries {
                    if let storagePath = entry.imageData["storage_path"] {
                        // Check if already cached
                        if Self.cachedImages[storagePath] == nil {
                            group.addTask {
                                await self.loadAndCacheImage(storagePath: storagePath)
                            }
                        }
                    }
                }
            }
        }
        
        private func loadAndCacheImage(storagePath: String) async {
            do {
                let imageUrl = try await SupabaseService.shared.getSignedImageURL(storagePath: storagePath)
                if let url = URL(string: imageUrl) {
                    // Use async URLSession instead of synchronous Data(contentsOf:)
                    let (data, _) = try await URLSession.shared.data(from: url)
                    if let image = UIImage(data: data) {
                        await MainActor.run {
                            Self.cachedImages[storagePath] = image
                        }
                        print("💾 Cached image: \(storagePath)")
                    }
                }
            } catch {
                print("❌ Failed to cache image \(storagePath): \(error)")
        }
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
                let date: Date
                let created_at: Date
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
                print("🔄 Found \(response.count) new entries since last update")
                
                // Convert to CalendarEntry objects
                var newEntries: [CalendarEntry] = []
                let currentUserId = try await SupabaseService.shared.client.auth.session.user.id
                
                for entry in response {
                    // Convert JSONValue to [String: String]
                    let imageData: [String: String]
                    if case .object(let dict) = entry.image_data {
                        imageData = dict.compactMapValues { value in
                            if case .string(let str) = value {
                                return str
                            } else if case .number(let num) = value {
                                return String(num)
                            }
                            return nil
                        }
                    } else {
                        continue
                    }
                    
                    // Convert date to string
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy-MM-dd"
                    let dateString = dateFormatter.string(from: entry.date)
                    
                    // Determine if entry is from partner
                    let isFromPartner = entry.created_by_user_id != currentUserId
                    
                    let calendarEntry = CalendarEntry(
                        id: entry.id,
                        imageData: imageData,
                        createdByUserId: entry.created_by_user_id,
                        isFromPartner: isFromPartner,
                        date: dateString
                    )
                    newEntries.append(calendarEntry)
                }
                
                // Merge new entries with existing ones
                await MainActor.run {
                    for entry in newEntries {
                        // Convert string date back to Date for dateKey function
                        let dateFormatter = DateFormatter()
                        dateFormatter.dateFormat = "yyyy-MM-dd"
                        if let date = dateFormatter.date(from: entry.date) {
                            let dateKey = self.dateKey(for: date)
                            if self.calendarEntries[dateKey] == nil {
                                self.calendarEntries[dateKey] = []
                            }
                            self.calendarEntries[dateKey]?.append(entry)
                        }
                    }
                    
                    // Update timestamp to the latest entry
                    if let latestEntry = newEntries.first {
                        let dateFormatter = DateFormatter()
                        dateFormatter.dateFormat = "yyyy-MM-dd"
                        if let date = dateFormatter.date(from: latestEntry.date) {
                            self.lastUpdateTimestamp = date
                        }
                    }
                }
                
                // Pre-cache new images
                await preCacheImages(for: newEntries)
            }
        } catch {
            print("❌ Failed to check for new entries: \(error)")
        }
    }
    
    private let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter
    }()
}

struct CalendarAccessGate: View {
    @State private var hasCouple = false
    @State private var showingPartnerConnection = false
    
    var body: some View {
        Group {
            if !hasCouple {
                VStack(spacing: 20) {
                    Image(systemName: "person.2.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    VStack(spacing: 8) {
                        Text("Connect with Your Partner")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Share your memories in a private calendar that only you and your partner can see.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    Button(action: { showingPartnerConnection = true }) {
                        HStack {
                            Image(systemName: "person.2.fill")
                            Text("Connect with Partner")
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
                }
                .padding()
                .background {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                }
                .padding(.horizontal)
            }
        }
        .task {
            let couple = await SupabaseService.shared.fetchCouple()
            await MainActor.run { self.hasCouple = (couple != nil) }
        }
        .sheet(isPresented: $showingPartnerConnection) {
            PartnerConnectionView()
                .onDisappear {
                    Task {
                        let couple = await SupabaseService.shared.fetchCouple()
                        await MainActor.run { self.hasCouple = (couple != nil) }
                    }
                }
        }
    }
}

struct CalendarDayView: View {
    let date: Date
    let isSelected: Bool
    let entries: [CalendarEntry]
    let showGiftForFutureMine: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                if showGiftForFutureMine {
                    Text("🎁")
                        .font(.system(size: 18))
                        .frame(width: 40, height: 40)
                } else if !entries.isEmpty {
                    // Show partner's latest upload, or your own if no partner uploads
                    let partnerEntries = entries.filter { $0.isFromPartner }
                    let entryToShow = partnerEntries.first ?? entries.first
                    
                    if let entry = entryToShow {
                        CalendarEntryThumbnail(entry: entry)
                            .frame(height: 40)
                    }
                } else {
                    Text("\(Calendar.current.component(.day, from: date))")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(isSelected ? .white : .primary)
                        .frame(width: 40, height: 40)
                        .background {
                        if isSelected {
                                Circle()
                                    .fill(Branding.primaryWarm)
                            } else {
                                Circle()
                                    .fill(.clear)
                            }
                        }
                }
            }
        }
        .buttonStyle(.plain)
    }
}

struct CalendarEntryThumbnail: View {
    let entry: CalendarEntry
    @State private var cachedImage: UIImage?
    @State private var imageUrl: String?
    
    var body: some View {
        Group {
            if let cachedImage = cachedImage {
                Image(uiImage: cachedImage)
                    .resizable()
                    .aspectRatio(1, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else if let imageUrl = imageUrl {
                AsyncImage(url: URL(string: imageUrl)) { image in
                    image
                        .resizable()
                        .aspectRatio(1, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } placeholder: {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.ultraThinMaterial)
                        .aspectRatio(1, contentMode: .fit)
                        .overlay {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                }
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.ultraThinMaterial)
                    .aspectRatio(1, contentMode: .fit)
                    .overlay {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
            }
        }
        .task {
            await loadImage()
        }
    }
    
    private func loadImage() async {
        // Try to get cached image first
        if let storagePath = entry.imageData["storage_path"] as? String {
            // Check if we have it in memory cache
            if let cachedImage = CalendarView.cachedImages[storagePath] {
                await MainActor.run {
                    self.cachedImage = cachedImage
                }
                return
            }
            
            // If not cached, download and cache
            do {
                let url = try await SupabaseService.shared.getSignedImageURL(storagePath: storagePath)
                if let imageUrl = URL(string: url) {
                    // Use async URLSession instead of synchronous Data(contentsOf:)
                    let (data, _) = try await URLSession.shared.data(from: imageUrl)
                    if let image = UIImage(data: data) {
                        // Cache the image in memory
                        CalendarView.cachedImages[storagePath] = image
                        
                        await MainActor.run {
                            self.cachedImage = image
                        }
                    } else {
                        await MainActor.run {
                            self.imageUrl = url
                        }
                    }
                } else {
                    await MainActor.run {
                        self.imageUrl = url
                    }
                }
            } catch {
                print("❌ Failed to load image: \(error)")
            }
        }
    }
}

struct CalendarEntryView: View {
    let entry: CalendarEntry
    @State private var cachedImage: UIImage?
    @State private var imageUrl: String?
    @State private var isLoading = true
    
    var body: some View {
        VStack(spacing: 8) {
            if let cachedImage = cachedImage {
                Image(uiImage: cachedImage)
                    .resizable()
                    .aspectRatio(1, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .frame(width: 120, height: 120)
            } else if let imageUrl = imageUrl {
                AsyncImage(url: URL(string: imageUrl)) { image in
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
                                .scaleEffect(1.2)
                        }
                }
                .frame(width: 120, height: 120)
            } else if isLoading {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .aspectRatio(1, contentMode: .fit)
                    .frame(width: 120, height: 120)
                    .overlay {
                        ProgressView()
                            .scaleEffect(1.2)
                    }
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .aspectRatio(1, contentMode: .fit)
                    .frame(width: 120, height: 120)
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundColor(.secondary)
                    }
            }
            
            // Show who uploaded it
            Text(entry.isFromPartner ? "From Partner" : "From You")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .task {
            await loadImage()
        }
    }
    
    private func loadImage() async {
        // Try to get cached image first
        if let storagePath = entry.imageData["storage_path"] as? String {
            if let cachedImage = CalendarView.cachedImages[storagePath] {
                await MainActor.run {
                    self.cachedImage = cachedImage
                    self.isLoading = false
                }
                return
            }
            
            // If not cached, download and cache
            do {
                let url = try await SupabaseService.shared.getSignedImageURL(storagePath: storagePath)
                if let imageUrl = URL(string: url) {
                    // Use async URLSession instead of synchronous Data(contentsOf:)
                    let (data, _) = try await URLSession.shared.data(from: imageUrl)
                    if let image = UIImage(data: data) {
                        // Cache the image
                        CalendarView.cachedImages[storagePath] = image
                        
                        await MainActor.run {
                            self.cachedImage = image
                            self.isLoading = false
                        }
                    } else {
                        await MainActor.run {
                            self.imageUrl = url
                            self.isLoading = false
                        }
                    }
                } else {
                    await MainActor.run {
                        self.imageUrl = url
                        self.isLoading = false
                    }
                }
            } catch {
                print("❌ Failed to load image: \(error)")
                await MainActor.run {
                    self.isLoading = false
                }
            }
        } else {
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
}

#Preview {
    CalendarView()
}


