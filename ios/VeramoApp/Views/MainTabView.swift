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
        .onAppear {
            // Notify widget to update when app opens
            NotificationCenter.default.post(name: NSNotification.Name("AppOpened"), object: nil)
        }
        .onChange(of: selectedTab) { _, newTab in
            // Trigger smart refresh when switching to Calendar or Today tabs
            if newTab == 0 || newTab == 1 {
                // Post notification to trigger smart refresh
                NotificationCenter.default.post(name: NSNotification.Name("SmartRefreshRequested"), object: nil)
            }
        }
    }
}

#Preview {
    MainTabView(authVM: AuthViewModel())
}
