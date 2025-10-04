//
//  VeramoWidget.swift
//  VeramoWidget
//
//  Created by Ömer Demirtaş on 4.10.2025.
//

import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), emoji: "😀")
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), emoji: "😀")
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        Task {
            let entry = await fetchPartnerUpdate()
            
            // Create timeline with multiple update points
            var entries: [SimpleEntry] = []
            let currentDate = Date()
            
            // Immediate entry
            entries.append(entry)
            
            // Add entries for the next few hours
            for hourOffset in 1...4 {
                let entryDate = Calendar.current.date(byAdding: .hour, value: hourOffset, to: currentDate)!
                let futureEntry = SimpleEntry(
                    date: entryDate,
                    partnerImage: entry.partnerImage,
                    partnerName: entry.partnerName,
                    lastUpdateDate: entry.lastUpdateDate
                )
                entries.append(futureEntry)
            }
            
            // More frequent updates: every 15 minutes
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
            let timeline = Timeline(entries: entries, policy: .after(nextUpdate))
            completion(timeline)
        }
    }
    
    private func fetchPartnerUpdate() async -> SimpleEntry {
        do {
            // Check if user is logged in
            guard let userId = await SharedSupabaseService.shared.getCurrentUser() else {
                return SimpleEntry(
                    date: Date(),
                    partnerImage: nil,
                    partnerName: "Veramo",
                    lastUpdateDate: "Please log in to see partner's memories"
                )
            }
            
            // Fetch couple information
            let couple = await SharedSupabaseService.shared.fetchCouple()
            guard let couple = couple else {
                return SimpleEntry(
                    date: Date(),
                    partnerImage: nil,
                    partnerName: "Veramo",
                    lastUpdateDate: "Connect with your partner to see memories"
                )
            }
            
            // Get partner ID
            let partnerId = couple.user1_id == userId ? couple.user2_id : couple.user1_id
            
            // Get partner's latest calendar entry (not future dates)
            let today = Date()
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let todayString = formatter.string(from: today)
            
            let supabase = SharedSupabaseService.shared.client
            let entries: [CalendarEntryRow] = try await supabase
                .from("calendar_entries")
                .select("id, date, created_at, image_data, created_by_user_id")
                .eq("couple_id", value: couple.id)
                .eq("created_by_user_id", value: partnerId)
                .lte("date", value: todayString)
                .order("created_at", ascending: false)
                .limit(1)
                .execute().value
            
            if let latestEntry = entries.first {
                // Get partner's name (we'll use a placeholder for now)
                let partnerName = "Partner"
                
                // Get image URL
                var imageUrl: String? = nil
                if case .object(let dict) = latestEntry.image_data,
                   let storagePath = dict["storage_path"],
                   case .string(let path) = storagePath {
                    imageUrl = try await SharedSupabaseService.shared.getSignedImageURL(storagePath: path)
                }
                
                // Format date
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "MMM d"
                let formattedDate = dateFormatter.string(from: latestEntry.created_at)
                
                return SimpleEntry(
                    date: Date(),
                    partnerImage: imageUrl,
                    partnerName: partnerName,
                    lastUpdateDate: formattedDate
                )
            } else {
                return SimpleEntry(
                    date: Date(),
                    partnerImage: nil,
                    partnerName: "Partner",
                    lastUpdateDate: "No memories yet"
                )
            }
        } catch {
            print("❌ Widget: Failed to fetch partner update: \(error)")
            return SimpleEntry(
                date: Date(),
                partnerImage: nil,
                partnerName: "Partner",
                lastUpdateDate: "Error loading"
            )
        }
    }

//    func relevances() async -> WidgetRelevances<Void> {
//        // Generate a list containing the contexts this widget is relevant in.
//    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let partnerImage: String?
    let partnerName: String
    let lastUpdateDate: String
}

struct VeramoWidgetEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("💖")
                    .font(.title2)
                Text(entry.partnerName)
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            if let imageUrl = entry.partnerImage {
                AsyncImage(url: URL(string: imageUrl)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [Color.pink.opacity(0.3), Color.purple.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(.white)
                        )
                }
                .frame(height: 120)
                .clipped()
                .cornerRadius(8)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [Color.pink.opacity(0.3), Color.purple.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 120)
                    .overlay(
                        VStack(spacing: 8) {
                            Image(systemName: "heart.fill")
                                .font(.title)
                                .foregroundColor(.white)
                            Text("Partner's Memory")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                        }
                    )
            }
            
            HStack {
                Text("Last update:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(entry.lastUpdateDate)
                    .font(.caption)
                    .fontWeight(.medium)
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
}

struct VeramoWidget: Widget {
    let kind: String = "VeramoWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            if #available(iOS 17.0, *) {
                VeramoWidgetEntryView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                VeramoWidgetEntryView(entry: entry)
                    .padding()
                    .background()
            }
        }
        .configurationDisplayName("Partner's Latest Memory")
        .description("Shows your partner's most recent calendar update.")
        .supportedFamilies([.systemMedium])
    }
}

#Preview(as: .systemMedium) {
    VeramoWidget()
} timeline: {
    SimpleEntry(date: .now, partnerImage: nil, partnerName: "Partner", lastUpdateDate: "Today")
}

// Helper structs for widget
struct CalendarEntryRow: Decodable {
    let id: UUID
    let date: String
    let created_at: Date
    let image_data: JSONValue
    let created_by_user_id: UUID
}

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
