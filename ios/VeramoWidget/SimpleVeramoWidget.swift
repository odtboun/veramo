import WidgetKit
import SwiftUI

// Simple widget implementation that can be easily added to Xcode
struct SimpleVeramoWidget: Widget {
    let kind: String = "SimpleVeramoWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SimpleProvider()) { entry in
            SimpleVeramoWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Partner's Memory")
        .description("Shows your partner's latest calendar update.")
        .supportedFamilies([.systemMedium])
    }
}

struct SimpleProvider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), partnerImage: nil, partnerName: "Partner", lastUpdateDate: "Today")
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), partnerImage: nil, partnerName: "Partner", lastUpdateDate: "Today")
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        // For now, just return a static entry
        // In a real implementation, you would fetch data from Supabase
        let entry = SimpleEntry(
            date: Date(),
            partnerImage: nil,
            partnerName: "Partner",
            lastUpdateDate: "Today"
        )
        
        let timeline = Timeline(entries: [entry], policy: .after(Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()))
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let partnerImage: String?
    let partnerName: String
    let lastUpdateDate: String
}

struct SimpleVeramoWidgetEntryView : View {
    var entry: SimpleEntry

    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Text("💖")
                    .font(.title2)
                Text(entry.partnerName)
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            // Image placeholder
            RoundedRectangle(cornerRadius: 12)
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
            
            // Footer
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

// Widget Bundle
@main
struct VeramoWidgetBundle: WidgetBundle {
    var body: some Widget {
        SimpleVeramoWidget()
    }
}

#Preview(as: .systemMedium) {
    SimpleVeramoWidget()
} timeline: {
    SimpleEntry(date: .now, partnerImage: nil, partnerName: "Partner", lastUpdateDate: "Today")
}
