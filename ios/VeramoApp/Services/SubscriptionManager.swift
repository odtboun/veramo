import Foundation
import Adapty
import AdaptyUI
import SwiftUI

@MainActor
class SubscriptionManager: ObservableObject, AdaptyDelegate {
    @Published var isSubscribed: Bool = false
    @Published var isLoading: Bool = true
    
    private let accessLevel = "premium" // Using Adapty's default premium access level
    private var paywallDelegate: PaywallDelegate?
    
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
            // Check couple subscription status
            do {
                let coupleHasAccess = try await SupabaseService.shared.checkCoupleSubscriptionStatus()
                self.isSubscribed = coupleHasAccess
                self.isLoading = false
                print("💑 Couple subscription status updated: \(self.isSubscribed ? "At least one partner subscribed" : "Neither partner subscribed")")
            } catch {
                print("❌ Error checking couple subscription status: \(error)")
                self.isSubscribed = false
                self.isLoading = false
            }
        }
    }
    
    // MARK: - Public Methods
    
    func checkSubscriptionStatus() async {
        do {
            // Check if either partner in the couple is subscribed
            let coupleHasAccess = try await SupabaseService.shared.checkCoupleSubscriptionStatus()
            isSubscribed = coupleHasAccess
            isLoading = false
            print("💑 Couple subscription status: \(isSubscribed ? "At least one partner subscribed" : "Neither partner subscribed")")
        } catch {
            print("❌ Error checking couple subscription status: \(error)")
            isSubscribed = false
            isLoading = false
        }
    }
    
    func hasAccess() -> Bool {
        return isSubscribed
    }
    
    // MARK: - Paywall Presentation
    
    func presentPaywallIfNeeded(placementId: String = "placement0") async -> Bool {
        // If already subscribed, allow the action
        if isSubscribed {
            return true
        }
        
        // Show paywall for non-subscribers
        await presentPaywall(placementId: placementId)
        return false
    }
    
    private func presentPaywall(placementId: String) async {
        do {
            print("🧾 Adapty: fetching paywall for placement=\(placementId)")
            let paywall = try await Adapty.getPaywall(placementId: placementId)
            print("✅ Adapty: fetched paywall name=\(paywall.name ?? "nil") placement=\(placementId)")
            
            let configuration = try await AdaptyUI.getPaywallConfiguration(forPaywall: paywall)
            print("✅ AdaptyUI: obtained paywall configuration")
            
            // Create and retain the delegate
            paywallDelegate = PaywallDelegate(subscriptionManager: self)
            let controller = try AdaptyUI.paywallController(with: configuration, delegate: paywallDelegate!)
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
    weak var subscriptionManager: SubscriptionManager?
    
    init(subscriptionManager: SubscriptionManager) {
        self.subscriptionManager = subscriptionManager
    }
    
    func paywallControllerDidFinishPurchase(_ controller: AdaptyPaywallController) {
        print("✅ Adapty: purchase flow finished")
        controller.dismiss(animated: true) {
            Task { @MainActor in
                await self.subscriptionManager?.checkSubscriptionStatus()
            }
        }
    }

    func paywallController(_ controller: AdaptyPaywallController, didFailPurchase product: any AdaptyPaywallProduct, error: AdaptyError) {
        print("⚠️ Adapty: purchase failed: \(error)")
    }

    func paywallControllerDidFinishRestore(_ controller: AdaptyPaywallController) {
        print("✅ Adapty: restore finished")
        controller.dismiss(animated: true) {
            Task { @MainActor in
                await self.subscriptionManager?.checkSubscriptionStatus()
            }
        }
    }

    func paywallController(_ controller: AdaptyPaywallController, didFinishRestoreWith profile: AdaptyProfile) {
        print("✅ Adapty: restore finished with profile")
        controller.dismiss(animated: true) {
            Task { @MainActor in
                await self.subscriptionManager?.checkSubscriptionStatus()
            }
        }
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
