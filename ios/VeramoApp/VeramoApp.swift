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
                    RootAfterAuthView(authVM: authVM)
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

struct RootAfterAuthView: View {
    @Bindable var authVM: AuthViewModel
    @State private var showOnboarding: Bool = false
    
    var body: some View {
        ContentView(authVM: authVM)
            .task {
                let completed = await SupabaseService.shared.isOnboardingCompleted()
                showOnboarding = !completed
            }
            .fullScreenCover(isPresented: $showOnboarding) {
                OnboardingFlow(partnerAlreadyOnboarded: false) {
                    Task { await SupabaseService.shared.setOnboardingCompleted() }
                    showOnboarding = false
                }
            }
    }
}
