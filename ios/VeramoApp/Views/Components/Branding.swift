import SwiftUI

enum Branding {
    static let primaryWarm = Color(red: 1.0, green: 0.42, blue: 0.35) // warm coral
    static let secondaryWarm = Color(red: 1.0, green: 0.64, blue: 0.30) // warm orange
    static let accentWarm = Color(red: 0.93, green: 0.36, blue: 0.70) // pink-magenta
    
    static var primaryGradient: LinearGradient {
        LinearGradient(colors: [primaryWarm, secondaryWarm], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    
    static var accentGradient: LinearGradient {
        LinearGradient(colors: [accentWarm.opacity(0.9), primaryWarm.opacity(0.9)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}


