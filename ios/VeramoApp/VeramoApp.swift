import SwiftUI
import Adapty

@main
struct VeramoApp: App {
    @State private var authVM = AuthViewModel()
    
    init() {
        Adapty.activate("public_live_t7iIHDB8.r2skT6vx7neXlUOITGFF")
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                if authVM.state == .signedIn {
                    ContentView(authVM: authVM)
                } else {
                    AuthView(authVM: authVM)
                }
            }
            .task {
                await authVM.refreshSession()
            }
            .onOpenURL { url in
                Task { try? await SupabaseService.shared.client.auth.session(from: url) }
            }
        }
    }
}
