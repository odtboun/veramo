import SwiftUI

@available(iOS 17.0, *)
struct LiquidGlassButton: View {
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
                .padding()
                .frame(maxWidth: .infinity)
                .background {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                        .overlay {
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(.white.opacity(0.2), lineWidth: 1)
                        }
                }
        }
        .buttonStyle(.plain)
    }
}

@available(iOS 17.0, *)
#Preview {
    LiquidGlassButton(title: "Liquid Glass Button") {
        print("Button tapped")
    }
    .padding()
    .background(.black)
}
