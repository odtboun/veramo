import SwiftUI

@main
struct VeramoApp: App {
    @State private var authVM = AuthViewModel()
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
