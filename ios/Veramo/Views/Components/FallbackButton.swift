import SwiftUI

struct FallbackButton: View {
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.blue)
                        .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    FallbackButton(title: "Fallback Button") {
        print("Button tapped")
    }
    .padding()
}
