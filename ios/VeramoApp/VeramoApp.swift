import UIKit
import SwiftUI
import Observation
import Adapty
import AdaptyUI

@main
struct VeramoApp: App {
    @State private var authVM = AuthViewModel()
    
    init() {
        Adapty.activate("public_live_t7iIHDB8.r2skT6vx7neXlUOITGFF")
        AdaptyUI.activate()
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                if authVM.state == .signedIn {
                    RootAfterAuthView(authVM: authVM)
                } else {
                    AuthView(authVM: authVM)
                }
            }
            .task {
                await authVM.refreshSession()
            }
            .onOpenURL { url in
                Task { try? await SupabaseService.shared.client.auth.session(from: url) }
            }
        }
    }
}

struct RootAfterAuthView: View {
    @Bindable var authVM: AuthViewModel
    @StateObject private var subscriptionManager = SubscriptionManager()
    @State private var showOnboarding: Bool = false
    @State private var pendingPaywallPlacement: String? = nil // kept for future AdaptyUI wiring
    @State private var shouldPresentPaywallAfterOnboarding: Bool = false
    
    var body: some View {
        ContentView(authVM: authVM, subscriptionManager: subscriptionManager)
            .task {
                let completed = await SupabaseService.shared.isOnboardingCompleted()
                showOnboarding = !completed
            }
            .fullScreenCover(isPresented: $showOnboarding) {
                OnboardingFlow(partnerAlreadyOnboarded: false) {
                    print("🎯 Onboarding finished: marking completed & scheduling paywall")
                    Task { await SupabaseService.shared.setOnboardingCompleted() }
                    // Defer actual presentation until the sheet dismisses
                    shouldPresentPaywallAfterOnboarding = true
                    showOnboarding = false
                }
                .onDisappear {
                    guard shouldPresentPaywallAfterOnboarding else { return }
                    shouldPresentPaywallAfterOnboarding = false
                    print("🧾 Adapty: presenting after onboarding dismissal")
                    Task { await presentAdaptyPaywall(placementId: "placement0") }
                }
            }
            .onChange(of: pendingPaywallPlacement) { _, newValue in
                guard let placementId = newValue else { return }
                print("🧾 Adapty: onChange detected placement = \(placementId)")
                Task { await presentAdaptyPaywall(placementId: placementId) }
                pendingPaywallPlacement = nil
            }
    }
}

extension RootAfterAuthView {
    @MainActor
    private func presentAdaptyPaywall(placementId: String) async {
        do {
            print("🧾 Adapty: fetching paywall for placement=\(placementId)")
            let paywall = try await Adapty.getPaywall(placementId: placementId)
            print("✅ Adapty: fetched paywall name=\(paywall.name ?? "nil") placement=\(placementId)")

            let configuration = try await AdaptyUI.getPaywallConfiguration(forPaywall: paywall)
            print("✅ AdaptyUI: obtained paywall configuration")
            let controller = try AdaptyUI.paywallController(with: configuration, delegate: PaywallDelegate())
            print("✅ AdaptyUI: created paywall controller")

            // The onboarding cover dismissal can race the presentation; retry a few times
            var attempt = 0
            var presented = false
            while attempt < 5 && !presented {
                if let presenter = topMostController() {
                    print("👆 Presenter ready (attempt=\(attempt)). Presenting paywall…")
                    presenter.present(controller, animated: true)
                    presented = true
                    print("📲 Adapty: paywall presented")
                    break
                } else {
                    attempt += 1
                    let delayMs = 250 * attempt
                    print("⏳ Presenter not ready (attempt=\(attempt)). Retrying in \(delayMs)ms…")
                    try? await Task.sleep(nanoseconds: UInt64(delayMs) * 1_000_000)
                }
            }
            if !presented { print("⚠️ Adapty: failed to find presenter after retries") }
        } catch {
            print("⚠️ Adapty paywall presentation failed: \(error)")
        }
    }

    private func topMostController(base: UIViewController? = UIApplication.shared.connectedScenes
        .compactMap { ($0 as? UIWindowScene)?.keyWindow }
        .first?.rootViewController) -> UIViewController? {
        if let nav = base as? UINavigationController { return topMostController(base: nav.visibleViewController) }
        if let tab = base as? UITabBarController, let selected = tab.selectedViewController { return topMostController(base: selected) }
        if let presented = base?.presentedViewController { return topMostController(base: presented) }
        return base
    }

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
            print("✅ Adapty: restore finished with profile \(profile)")
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
                print("🧹 Adapty: action .close received, dismissing paywall")
                controller.dismiss(animated: true)
            default:
                break
            }
        }
    }
}

