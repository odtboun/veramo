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
        SimpleEntry(date: Date(), partnerImage: nil, partnerName: "Partner", lastUpdateDate: "Today")
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), partnerImage: nil, partnerName: "Partner", lastUpdateDate: "Today")
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        print("🚀 Widget: getTimeline called")
        Task {
            print("🚀 Widget: Starting fetchPartnerUpdate task")
            let entry = await fetchPartnerUpdate()
            print("🚀 Widget: fetchPartnerUpdate completed")
            
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
            print("🚀 Widget: Timeline created with \(entries.count) entries")
            completion(timeline)
        }
    }
    
    private func fetchPartnerUpdate() async -> SimpleEntry {
        print("🔍 Widget: Starting fetchPartnerUpdate")
        
        // Read from shared App Groups data
        let userDefaults = UserDefaults(suiteName: "group.com.omerdemirtas.veramo")
        print("📱 Widget: UserDefaults suite: \(userDefaults != nil ? "Found" : "Nil")")
        
        let imageUrl = userDefaults?.string(forKey: "latestImageUrl")
        let partnerName = userDefaults?.string(forKey: "partnerName") ?? "Partner"
        let lastUpdateDate = userDefaults?.string(forKey: "lastUpdateDate") ?? "No updates"
        
        print("📱 Widget: Retrieved data - Image: \(imageUrl != nil ? "Found" : "None"), Partner: \(partnerName), Date: \(lastUpdateDate)")
        if let imageUrl = imageUrl {
            print("📱 Widget: Full image URL: \(imageUrl)")
            print("📱 Widget: Testing URL validity: \(URL(string: imageUrl) != nil ? "Valid" : "Invalid")")
        } else {
            print("📱 Widget: No image URL found in shared data")
        }
        
        // Debug: List all keys in UserDefaults
        if let userDefaults = userDefaults {
            let allKeys = userDefaults.dictionaryRepresentation().keys
            print("📱 Widget: All UserDefaults keys: \(Array(allKeys))")
        }
        
        return SimpleEntry(
            date: Date(),
            partnerImage: imageUrl,
            partnerName: partnerName,
            lastUpdateDate: lastUpdateDate
        )
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
        if let imageUrl = entry.partnerImage, let url = URL(string: imageUrl) {
            // Try to load from local storage first
            if let localImage = loadLocalImage(from: url) {
                Image(uiImage: localImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea()
            } else {
                // Fallback to system image if no local image
                ZStack {
                    LinearGradient(
                        colors: [Color.pink.opacity(0.3), Color.purple.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()
                    
                    Image(systemName: "heart.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.pink)
                        .scaleEffect(1.6)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()
            }
        } else {
            // No image URL - show placeholder
            ZStack {
                LinearGradient(
                    colors: [Color.pink.opacity(0.3), Color.purple.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                Image(systemName: "heart.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.pink)
                    .scaleEffect(1.6)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
        }
    }
    
    private func loadLocalImage(from url: URL) -> UIImage? {
        // Get the cached filename from UserDefaults
        let userDefaults = UserDefaults(suiteName: "group.com.omerdemirtas.veramo")
        let cachedFilename = userDefaults?.string(forKey: "cachedImageFilename")
        
        // Use shared container for cache directory
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.omerdemirtas.veramo") else {
            print("📱 Widget: Failed to get shared container URL")
            return nil
        }
        let cacheDirectory = containerURL.appendingPathComponent("widget_cache")
        
        // Try to use the cached filename first, fallback to URL filename
        let filename = cachedFilename ?? url.lastPathComponent
        let localURL = cacheDirectory.appendingPathComponent(filename)
        
        print("📱 Widget: Looking for local image at: \(localURL.path)")
        print("📱 Widget: Using filename: \(filename)")
        print("📱 Widget: File exists: \(FileManager.default.fileExists(atPath: localURL.path))")
        
        guard let data = try? Data(contentsOf: localURL) else { 
            print("📱 Widget: Failed to load local image data, trying to download directly...")
            // Fallback: try to download the image directly
            return downloadImageDirectly(from: url)
        }
        
        guard let image = UIImage(data: data) else {
            print("📱 Widget: Failed to create UIImage from data")
            return nil
        }
        
        print("📱 Widget: Successfully loaded local image")
        return image
    }
    
    private func downloadImageDirectly(from url: URL) -> UIImage? {
        print("📱 Widget: Downloading image directly from: \(url.absoluteString)")
        
        // Use a semaphore to make this synchronous
        var result: UIImage? = nil
        let semaphore = DispatchSemaphore(value: 0)
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            defer { semaphore.signal() }
            
            if let error = error {
                print("📱 Widget: Download error: \(error)")
                return
            }
            
            guard let data = data else {
                print("📱 Widget: No data received")
                return
            }
            
            result = UIImage(data: data)
            if result != nil {
                print("📱 Widget: Successfully downloaded and created image")
            } else {
                print("📱 Widget: Failed to create UIImage from downloaded data")
            }
        }.resume()
        
        // Wait for download to complete (with timeout)
        let timeout = DispatchTime.now() + .seconds(10)
        if semaphore.wait(timeout: timeout) == .timedOut {
            print("📱 Widget: Download timeout")
            return nil
        }
        
        return result
    }
}

struct VeramoWidget: Widget {
    let kind: String = "VeramoWidgetV14"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            if let imageUrl = entry.partnerImage, let url = URL(string: imageUrl) {
                VeramoWidgetEntryView(entry: entry)
                    .containerBackground(.clear, for: .widget)
            } else {
                VeramoWidgetEntryView(entry: entry)
                    .containerBackground(
                        LinearGradient(
                            colors: [Color.pink.opacity(0.3), Color.purple.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        for: .widget
                    )
            }
        }
        .configurationDisplayName("Partner's Latest Memory")
        .description("Shows your partner's most recent calendar update.")
        .supportedFamilies([.systemSmall])
    }
}

#Preview(as: .systemSmall) {
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
