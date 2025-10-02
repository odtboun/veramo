import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            
            Text("Welcome to Veramo")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Your mobile app with adaptive UI components")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            VStack(spacing: 16) {
                AdaptiveButton(title: "Get Started") {
                    print("Get Started tapped")
                }
                
                AdaptiveButton(title: "Learn More") {
                    print("Learn More tapped")
                }
            }
            .padding(.horizontal)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
