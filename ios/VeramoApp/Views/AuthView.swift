import SwiftUI
import AuthenticationServices
import Observation

struct AuthView: View {
    @Bindable var authVM: AuthViewModel
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "heart.fill")
                .font(.system(size: 60))
                .foregroundColor(.pink)
            
            Text("Welcome to Veramo")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Text("This screen is for testers, there won't be a login step before the onboarding flow in the live version.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Button {
                Task { @MainActor in
                    if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let window = scene.keyWindow {
                        await authVM.signInWithGoogle(presentationAnchor: window)
                    }
                }
            } label: {
                HStack {
                    Image(systemName: "g.circle.fill")
                    Text("Continue with Google")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 12).fill(.blue))
            }
            .buttonStyle(.plain)
            
            Button {
                Task { @MainActor in
                    if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let window = scene.keyWindow {
                        await authVM.signInWithApple(presentationAnchor: window)
                    }
                }
            } label: {
                HStack {
                    Image(systemName: "apple.logo")
                    Text("Continue with Apple")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 12).fill(.black))
            }
            .buttonStyle(.plain)
            
            Spacer()
        }
        .padding()
    }
}

#Preview {
    AuthView(authVM: AuthViewModel())
}



