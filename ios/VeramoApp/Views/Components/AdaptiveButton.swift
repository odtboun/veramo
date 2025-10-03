import SwiftUI

struct AdaptiveButton: View {
    let title: String
    let action: () -> Void
    
    var body: some View {
        if #available(iOS 17.0, *) {
            LiquidGlassButton(title: title, action: action)
        } else {
            FallbackButton(title: title, action: action)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        AdaptiveButton(title: "Adaptive Button") {
            print("Button tapped")
        }
        .padding()
    }
}
