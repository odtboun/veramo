import SwiftUI
import Observation

struct ContentView: View {
    @Bindable var authVM: AuthViewModel
    var body: some View {
        MainTabView(authVM: authVM)
    }
}

#Preview {
    ContentView(authVM: AuthViewModel())
}
