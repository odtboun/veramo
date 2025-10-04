import WidgetKit
import Foundation

class WidgetUpdateManager {
    static let shared = WidgetUpdateManager()
    
    private init() {}
    
    // Force widget to update immediately
    func updateWidget() {
        WidgetCenter.shared.reloadAllTimelines()
        print("🔄 Widget: Forced update triggered")
    }
    
    // Update specific widget kind
    func updateVeramoWidget() {
        WidgetCenter.shared.reloadTimelines(ofKind: "VeramoWidget")
        print("🔄 Widget: VeramoWidget timeline reloaded")
    }
}

// Extension to handle app open notifications
extension WidgetUpdateManager {
    func setupAppOpenListener() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("AppOpened"),
            object: nil,
            queue: .main
        ) { _ in
            // Update widget when app opens
            self.updateVeramoWidget()
        }
    }
}
