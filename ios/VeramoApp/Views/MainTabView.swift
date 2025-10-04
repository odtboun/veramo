import SwiftUI
import Observation

struct MainTabView: View {
    @State private var selectedTab = 0
    @Bindable var authVM: AuthViewModel
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Home / Today View
            TodayView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Today")
                }
                .tag(0)
            
            // Shared Calendar
            CalendarView()
                .tabItem {
                    Image(systemName: "calendar")
                    Text("Calendar")
                }
                .tag(1)
            
            // Settings
            SettingsView(authVM: authVM)
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text("Settings")
                }
                .tag(2)
        }
        .accentColor(.primary)
    }
}

#Preview {
    MainTabView(authVM: AuthViewModel())
}
