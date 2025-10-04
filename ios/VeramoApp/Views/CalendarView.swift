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
                                .foregroundColor(.blue)
                        }
                        
                        Spacer()
                        
                        Text(currentMonth, formatter: monthFormatter)
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        Button(action: nextMonth) {
                            Image(systemName: "chevron.right")
                                .font(.title2)
                                .foregroundColor(.blue)
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
                                    CalendarDayView(
                                        date: date,
                                        isSelected: Calendar.current.isDate(date, inSameDayAs: selectedDate),
                                        entries: calendarEntries[dateKey(for: date)] ?? []
                                    ) {
                                        selectedDate = date
                                    }
                                }
                            }
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
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            showingAddMemory = true
                        }) {
                            HStack {
                                Image(systemName: "plus")
                                Text("Add Memory")
                            }
                        }
                    }
                }
                .sheet(isPresented: $showingAddMemory) {
                    AddMemoryView()
                }
                .onAppear {
                    Task { await loadCalendarData() }
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
    
        private func loadCalendarData() async {
            await MainActor.run { self.isLoading = true }
            
            do {
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
                
                // Convert to CalendarEntry objects
                let userId = try await SupabaseService.shared.currentUserId()
                let calendarEntries = entries.map { entry in
                    // Convert image_data to [String: String] format
                    let imageData: [String: String]
                    switch entry.image_data {
                    case .object(let dict):
                        imageData = dict.mapValues { $0.stringValue }
                    default:
                        imageData = [:]
                    }
                    
                    return CalendarEntry(
                        id: entry.id,
                        imageData: imageData,
                        createdByUserId: entry.created_by_user_id,
                        isFromPartner: entry.created_by_user_id != userId,
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
                
                await MainActor.run {
                    self.calendarEntries = groupedEntries
                    self.isLoading = false
                }
                
            } catch {
                print("❌ Failed to load calendar data: \(error)")
                await MainActor.run { self.isLoading = false }
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
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                if !entries.isEmpty {
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
                                    .fill(.blue)
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
    @State private var imageUrl: String?
    
    var body: some View {
        Group {
            if let imageUrl = imageUrl {
                AsyncImage(url: URL(string: imageUrl)) { image in
                    image
                        .resizable()
                        .aspectRatio(1, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } placeholder: {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.ultraThinMaterial)
                        .aspectRatio(1, contentMode: .fit)
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
            await loadImageUrl()
        }
    }
    
        private func loadImageUrl() async {
            do {
                // Get the image URL from the image data
                if let storagePath = entry.imageData["storage_path"] as? String {
                    let url = try await SupabaseService.shared.getSignedImageURL(storagePath: storagePath)
                    await MainActor.run {
                        self.imageUrl = url
                    }
                }
            } catch {
                print("❌ Failed to load image URL: \(error)")
            }
        }
}

struct CalendarEntryView: View {
    let entry: CalendarEntry
    @State private var imageUrl: String?
    @State private var isLoading = true
    
    var body: some View {
        VStack(spacing: 8) {
            if let imageUrl = imageUrl {
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
            await loadImageUrl()
        }
    }
    
        private func loadImageUrl() async {
            do {
                // Get the image URL from the image data
                if let storagePath = entry.imageData["storage_path"] as? String {
                    let url = try await SupabaseService.shared.getSignedImageURL(storagePath: storagePath)
                    await MainActor.run {
                        self.imageUrl = url
                        self.isLoading = false
                    }
                } else {
                    await MainActor.run {
                        self.isLoading = false
                    }
                }
            } catch {
                print("❌ Failed to load image URL: \(error)")
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
}

#Preview {
    CalendarView()
}
