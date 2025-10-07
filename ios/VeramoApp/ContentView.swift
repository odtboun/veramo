import SwiftUI
import Observation

struct ContentView: View {
    @Bindable var authVM: AuthViewModel
    @ObservedObject var subscriptionManager: SubscriptionManager
    
    var body: some View {
        MainTabView(authVM: authVM, subscriptionManager: subscriptionManager)
    }
}

#Preview {
    ContentView(authVM: AuthViewModel(), subscriptionManager: SubscriptionManager())
}
