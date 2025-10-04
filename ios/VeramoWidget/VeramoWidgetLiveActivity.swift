//
//  VeramoWidgetLiveActivity.swift
//  VeramoWidget
//
//  Created by Ömer Demirtaş on 4.10.2025.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct VeramoWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct VeramoWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: VeramoWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension VeramoWidgetAttributes {
    fileprivate static var preview: VeramoWidgetAttributes {
        VeramoWidgetAttributes(name: "World")
    }
}

extension VeramoWidgetAttributes.ContentState {
    fileprivate static var smiley: VeramoWidgetAttributes.ContentState {
        VeramoWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: VeramoWidgetAttributes.ContentState {
         VeramoWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: VeramoWidgetAttributes.preview) {
   VeramoWidgetLiveActivity()
} contentStates: {
    VeramoWidgetAttributes.ContentState.smiley
    VeramoWidgetAttributes.ContentState.starEyes
}
