import SwiftUI
import Supabase

struct CalendarView: View {
    @State private var selectedDate = Date()
    @State private var currentMonth = Date()
    @State private var calendarImages: [String: [String]] = [:]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Lock if no couple
                CalendarAccessGate()
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
                        ForEach(["S", "M", "T", "W", "T", "F", "S"], id: \.self) { day in
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
                                hasImage: calendarImages[dateKey(for: date)] != nil,
                                imageUrl: calendarImages[dateKey(for: date)]?.first
                            ) {
                                selectedDate = date
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Selected date details
                if let images = calendarImages[dateKey(for: selectedDate)], !images.isEmpty {
                    VStack(spacing: 16) {
                        Divider()
                        
                        Text("Memories for \(selectedDate, formatter: dateFormatter)")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(images, id: \.self) { imageUrl in
                                    AsyncImage(url: URL(string: imageUrl)) { image in
                                        image
                                            .resizable()
                                            .aspectRatio(1, contentMode: .fit)
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                    } placeholder: {
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(.ultraThinMaterial)
                                            .aspectRatio(1, contentMode: .fit)
                                    }
                                    .frame(width: 120, height: 120)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Our Calendar")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                loadSampleData()
            }
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
    
    private func loadSampleData() {
        // Add some sample images to random dates
        let today = Date()
        for i in 0..<5 {
            if let date = Calendar.current.date(byAdding: .day, value: -i, to: today) {
                let key = dateKey(for: date)
                calendarImages[key] = ["https://picsum.photos/400/400?random=\(i + 100)"]
            }
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
            let couple = await SupabaseService.shared.fetchCoupleId()
            await MainActor.run { self.hasCouple = (couple != nil) }
        }
        .sheet(isPresented: $showingPartnerConnection) {
            // TODO: Add PartnerConnectionView back to project
            Text("Partner Connection")
                .onDisappear {
                    Task {
                        let couple = await SupabaseService.shared.fetchCoupleId()
                        await MainActor.run { self.hasCouple = (couple != nil) }
                    }
                }
        }
    }
}

struct CalendarDayView: View {
    let date: Date
    let isSelected: Bool
    let hasImage: Bool
    let imageUrl: String?
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
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
                    .frame(height: 40)
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
                            } else if hasImage {
                                Circle()
                                    .fill(.blue.opacity(0.2))
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

#Preview {
    CalendarView()
}
