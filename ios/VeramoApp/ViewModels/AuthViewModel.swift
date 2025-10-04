import Foundation
import Observation
import AuthenticationServices
import Supabase
import CryptoKit

// Simple shared data manager for widget communication
class SharedDataManager {
    static let shared = SharedDataManager()
    private let userDefaults = UserDefaults(suiteName: "group.com.omerdemirtas.veramo")
    
    private init() {}
    
    func storeUserSession(userId: String, accessToken: String, refreshToken: String) {
        userDefaults?.set(userId, forKey: "userId")
        userDefaults?.set(accessToken, forKey: "accessToken")
        userDefaults?.set(refreshToken, forKey: "refreshToken")
        userDefaults?.set(Date(), forKey: "lastUpdated")
        print("📱 SharedDataManager: Stored user session for user: \(userId)")
    }
    
    func getUserId() -> String? {
        return userDefaults?.string(forKey: "userId")
    }
    
    func clearSession() {
        userDefaults?.removeObject(forKey: "userId")
        userDefaults?.removeObject(forKey: "accessToken")
        userDefaults?.removeObject(forKey: "refreshToken")
        userDefaults?.removeObject(forKey: "lastUpdated")
        print("📱 SharedDataManager: Cleared user session")
    }
    
    // Widget data sharing
    func storeLatestImageData(imageUrl: String, partnerName: String, lastUpdateDate: String) {
        print("📱 SharedDataManager: UserDefaults suite: \(userDefaults != nil ? "Found" : "Nil")")
        
        userDefaults?.set(imageUrl, forKey: "latestImageUrl")
        userDefaults?.set(partnerName, forKey: "partnerName")
        userDefaults?.set(lastUpdateDate, forKey: "lastUpdateDate")
        userDefaults?.set(Date(), forKey: "widgetLastUpdated")
        print("📱 SharedDataManager: Stored latest image data for widget")
        print("📱 SharedDataManager: Image URL: \(imageUrl)")
        print("📱 SharedDataManager: Partner: \(partnerName)")
        print("📱 SharedDataManager: Date: \(lastUpdateDate)")
        
        // Download and cache image locally for widget
        Task {
            await downloadAndCacheImage(imageUrl: imageUrl)
        }
        
        // Force synchronize to ensure data is written
        userDefaults?.synchronize()
        print("📱 SharedDataManager: Data synchronized")
        
        // Verify the data was stored
        let storedUrl = userDefaults?.string(forKey: "latestImageUrl")
        let storedPartner = userDefaults?.string(forKey: "partnerName")
        let storedDate = userDefaults?.string(forKey: "lastUpdateDate")
        print("📱 SharedDataManager: Verification - URL: \(storedUrl ?? "nil"), Partner: \(storedPartner ?? "nil"), Date: \(storedDate ?? "nil")")
        
        // Debug: List all keys in UserDefaults
        if let userDefaults = userDefaults {
            let allKeys = userDefaults.dictionaryRepresentation().keys
            print("📱 SharedDataManager: All UserDefaults keys: \(Array(allKeys))")
        }
    }
    
    private func downloadAndCacheImage(imageUrl: String) async {
        print("📱 SharedDataManager: Starting to download image: \(imageUrl)")
        guard let url = URL(string: imageUrl) else { 
            print("📱 SharedDataManager: Invalid URL")
            return 
        }
        
        do {
            print("📱 SharedDataManager: Downloading image data...")
            let (data, _) = try await URLSession.shared.data(from: url)
            print("📱 SharedDataManager: Downloaded \(data.count) bytes")
            
            // Create widget cache directory in shared container
            guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.omerdemirtas.veramo") else {
                print("📱 SharedDataManager: Failed to get shared container URL")
                return
            }
            let cacheDirectory = containerURL.appendingPathComponent("widget_cache")
            print("📱 SharedDataManager: Cache directory: \(cacheDirectory.path)")
            
            // Create directory if it doesn't exist
            try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
            print("📱 SharedDataManager: Created cache directory")
            
            // Save image to cache with a consistent filename
            let filename = url.lastPathComponent
            let localURL = cacheDirectory.appendingPathComponent(filename)
            try data.write(to: localURL)
            
            print("📱 SharedDataManager: Successfully cached image locally: \(localURL.path)")
            print("📱 SharedDataManager: File exists after write: \(FileManager.default.fileExists(atPath: localURL.path))")
            
            // Also store the filename in UserDefaults for the widget to use
            userDefaults?.set(filename, forKey: "cachedImageFilename")
            print("📱 SharedDataManager: Stored cached filename: \(filename)")
        } catch {
            print("📱 SharedDataManager: Failed to cache image: \(error)")
        }
    }
    
    func getLatestImageData() -> (imageUrl: String?, partnerName: String?, lastUpdateDate: String?) {
        let imageUrl = userDefaults?.string(forKey: "latestImageUrl")
        let partnerName = userDefaults?.string(forKey: "partnerName")
        let lastUpdateDate = userDefaults?.string(forKey: "lastUpdateDate")
        return (imageUrl, partnerName, lastUpdateDate)
    }
}

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
                        // Store session data for widget
                        SharedDataManager.shared.storeUserSession(
                            userId: session.user.id.uuidString,
                            accessToken: session.accessToken,
                            refreshToken: session.refreshToken ?? ""
                        )
                    }
                } else {
                    await MainActor.run {
                        self.email = nil
                        self.state = .signedOut
                        // Clear session data
                        SharedDataManager.shared.clearSession()
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
            // Store session data for widget
            SharedDataManager.shared.storeUserSession(
                userId: session.user.id.uuidString,
                accessToken: session.accessToken,
                refreshToken: session.refreshToken ?? ""
            )
        } catch {
            self.state = .signedOut
            // Clear session data
            SharedDataManager.shared.clearSession()
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


