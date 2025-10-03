import Foundation
import Observation
import AuthenticationServices
import Supabase
import CryptoKit

@Observable
final class AuthViewModel: NSObject {
    enum AuthState {
        case signedOut
        case signedIn
    }

    private let supabase = SupabaseService.shared.client
    var state: AuthState = .signedOut
    var email: String?
    private var currentNonce: String?

    override init() {
        super.init()
        Task { await refreshSession() }
        Task {
            for await change in supabase.auth.authStateChanges {
                if let session = change.session {
                    await MainActor.run {
                        self.email = session.user.email
                        self.state = .signedIn
                    }
                } else {
                    await MainActor.run {
                        self.email = nil
                        self.state = .signedOut
                    }
                }
            }
        }
    }

    @MainActor
    func refreshSession() async {
        do {
            let session = try await supabase.auth.session
            self.email = session.user.email
            self.state = .signedIn
        } catch {
            self.state = .signedOut
        }
    }

    @MainActor
    func signInWithApple(presentationAnchor: ASPresentationAnchor) async {
        // Use native Sign in with Apple with nonce (works on simulator if iCloud is signed in)
        let nonce = Self.randomNonceString()
        currentNonce = nonce
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    @MainActor
    func signInWithGoogle(presentationAnchor: ASPresentationAnchor) async {
        do {
            let callbackScheme = "veramo"
            let redirect = URL(string: "\(callbackScheme)://auth-callback")!
            let url = try await supabase.auth.getOAuthSignInURL(provider: .google, redirectTo: redirect)

            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: callbackScheme
            ) { url, _ in
                guard let url else { return }
                Task { try? await self.supabase.auth.session(from: url); await self.refreshSession() }
            }
            session.prefersEphemeralWebBrowserSession = true
            session.presentationContextProvider = self
            session.start()
            await refreshSession()
        } catch {
            print("Google sign-in failed: \(error)")
        }
    }

    @MainActor
    func signOut() async {
        do {
            try await supabase.auth.signOut()
            self.state = .signedOut
            self.email = nil
        } catch {
            print("Sign out failed: \(error)")
        }
    }
}

// MARK: - ASAuthorizationControllerDelegate & Presentation
extension AuthViewModel: ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding, ASWebAuthenticationPresentationContextProviding {
    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.keyWindow ?? UIWindow()
    }

    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.keyWindow ?? UIWindow()
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else { return }
        guard let identityTokenData = appleIDCredential.identityToken,
              let idToken = String(data: identityTokenData, encoding: .utf8) else { return }
        let nonce = currentNonce

        Task { @MainActor in
            do {
                _ = try await supabase.auth.signInWithIdToken(
                    credentials: .init(
                        provider: .apple,
                        idToken: idToken,
                        nonce: nonce
                    )
                )
                await self.refreshSession()
            } catch {
                print("Apple sign-in failed: \(error)")
            }
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        print("Apple sign-in error: \(error)")
    }
}

// MARK: - Nonce helpers
extension AuthViewModel {
    static func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: Array<Character> = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            let randoms: [UInt8] = (0..<16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess { fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)") }
                return random
            }

            randoms.forEach { random in
                if remainingLength == 0 { return }
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }

        return result
    }

    static func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
}


