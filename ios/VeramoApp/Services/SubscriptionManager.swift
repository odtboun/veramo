import Foundation
import Adapty
import AdaptyUI
import SwiftUI

@MainActor
class SubscriptionManager: ObservableObject, AdaptyDelegate {
    @Published var isSubscribed: Bool = false
    @Published var isLoading: Bool = true
    
    private let accessLevel = "premium" // Using Adapty's default premium access level
    
    init() {
        // Set delegate to receive automatic profile updates
        Adapty.delegate = self
        Task {
            await checkSubscriptionStatus()
        }
    }
    
    // MARK: - AdaptyDelegate
    
    nonisolated func didLoadLatestProfile(_ profile: AdaptyProfile) {
        Task { @MainActor in
            self.isSubscribed = profile.accessLevels[self.accessLevel]?.isActive ?? false
            self.isLoading = false
            print("📱 Subscription status updated: \(self.isSubscribed ? "Subscribed" : "Not subscribed")")
        }
    }
    
    // MARK: - Public Methods
    
    func checkSubscriptionStatus() async {
        do {
            let profile = try await Adapty.getProfile()
            isSubscribed = profile.accessLevels[accessLevel]?.isActive ?? false
            isLoading = false
            print("📱 Current subscription status: \(isSubscribed ? "Subscribed" : "Not subscribed")")
        } catch {
            print("❌ Error checking subscription status: \(error)")
            isSubscribed = false
            isLoading = false
        }
    }
    
    func hasAccess() -> Bool {
        return isSubscribed
    }
    
    // MARK: - Paywall Presentation
    
    func presentPaywallIfNeeded() async -> Bool {
        // If already subscribed, allow the action
        if isSubscribed {
            return true
        }
        
        // Show paywall for non-subscribers
        await presentPaywall()
        return false
    }
    
    private func presentPaywall() async {
        do {
            print("🧾 Adapty: fetching paywall for placement=placement0")
            let paywall = try await Adapty.getPaywall(placementId: "placement0")
            print("✅ Adapty: fetched paywall name=\(paywall.name ?? "nil") placement=placement0")
            
            let configuration = try await AdaptyUI.getPaywallConfiguration(forPaywall: paywall)
            print("✅ AdaptyUI: obtained paywall configuration")
            
            let controller = try AdaptyUI.paywallController(with: configuration, delegate: PaywallDelegate())
            print("✅ AdaptyUI: created paywall controller")
            
            // Present from the topmost view controller
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootViewController = window.rootViewController {
                
                var topController = rootViewController
                while let presentedController = topController.presentedViewController {
                    topController = presentedController
                }
                
                print("👆 Presenter ready: \(type(of: topController)). Presenting paywall...")
                topController.present(controller, animated: true) {
                    print("📲 Adapty: paywall presented")
                }
            } else {
                print("⚠️ Could not find top view controller to present paywall")
            }
        } catch {
            print("⚠️ Adapty paywall presentation failed: \(error)")
        }
    }
}

// MARK: - PaywallDelegate

private final class PaywallDelegate: NSObject, AdaptyPaywallControllerDelegate {
    func paywallControllerDidFinishPurchase(_ controller: AdaptyPaywallController) {
        print("✅ Adapty: purchase flow finished")
    }

    func paywallController(_ controller: AdaptyPaywallController, didFailPurchase product: any AdaptyPaywallProduct, error: AdaptyError) {
        print("⚠️ Adapty: purchase failed: \(error)")
    }

    func paywallControllerDidFinishRestore(_ controller: AdaptyPaywallController) {
        print("✅ Adapty: restore finished")
    }

    func paywallController(_ controller: AdaptyPaywallController, didFinishRestoreWith profile: AdaptyProfile) {
        print("✅ Adapty: restore finished with profile")
    }

    func paywallController(_ controller: AdaptyPaywallController, didFailRestoreWith error: AdaptyError) {
        print("⚠️ Adapty: restore failed: \(error)")
    }

    // Dismiss when user taps the close (X) button
    func paywallControllerDidPressClose(_ controller: AdaptyPaywallController) {
        print("🧹 Adapty: close pressed, dismissing paywall")
        controller.dismiss(animated: true)
    }

    // Fallback for templates that emit generic actions (including close)
    func paywallController(_ controller: AdaptyPaywallController, didPerform action: AdaptyUI.Action) {
        switch action {
        case .close:
            print("🧹 Adapty: close action performed, dismissing paywall")
            controller.dismiss(animated: true)
        default:
            print("🔧 Adapty: other action performed: \(action)")
        }
    }
}
