import AppKit
import AuthenticationServices
import Foundation

@Observable
@MainActor
final class AccountService {
    static let shared = AccountService()

    private(set) var isLoading: Bool = false
    private(set) var lastError: String?
    private(set) var isSigningIn: Bool = false
    private(set) var isBuyingCredits: Bool = false

    var isMisconfigured: Bool { !QwenAccountService.shared.isConfigured }

    var isSignedIn: Bool { QwenAccountService.shared.isConfigured }

    var isPaid: Bool {
        switch QwenAccountService.shared.mode {
        case .backend: true
        case .direct: QwenAccountService.shared.canUseDirectAPI
        }
    }

    var hasCredits: Bool { true }

    var remainingCredits: Int { subscriptionInfo?.creditsRemaining ?? .max }

    var aiAllowed: Bool { isSignedIn }

    var budgetCredits: Int? { nil }
    var spentCredits: Int = 0

    var account: AccountUser? { _account }
    var tier: AccountTier { _tier }
    var availablePlans: [AvailablePlan] { _availablePlans }

    func availablePlan(for tier: AccountTier) -> AvailablePlan? {
        _availablePlans.first { $0.tier == tier }
    }

    private var _account: AccountUser?
    private var _tier: AccountTier = .pro
    private var _availablePlans: [AvailablePlan] = []
    private var subscriptionInfo: SubscriptionInfo?

    private init() {
        refreshSubscription()
    }

    func configure() {
        Log.account.notice("account configured")
        refreshSubscription()
    }

    func signInWithGoogle() async {
        lastError = nil
        isSigningIn = true
        defer { isSigningIn = false }

        do {
            _ = try await GoogleAuthService.signIn()
            refreshSubscription()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func signOut() async {
        GoogleAuthService.signOut()
        QwenKeychain.deleteKey()
        _account = nil
        _tier = .none
        subscriptionInfo = nil
    }

    func subscribe(tier: AccountTier) async {
        lastError = nil
        isLoading = true
        defer { isLoading = false }

        let priceId: String
        switch tier {
        case .pro: priceId = "price_pro_monthly"
        case .max: priceId = "price_max_monthly"
        case .none: return
        }

        do {
            let url = try await DodoPaymentsService.createCheckoutSession(priceId: priceId)
            let session = DodoPaymentsSession()
            try await session.start(url: url)
            refreshSubscription()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func buyCredits(dollars: Int) {
        lastError = nil
        isBuyingCredits = true
        Task {
            defer { isBuyingCredits = false }
            do {
                let url = try await DodoPaymentsService.createCheckoutSession(priceId: "price_credits_\(dollars)")
                let session = DodoPaymentsSession()
                try await session.start(url: url)
                refreshSubscription()
            } catch {
                lastError = error.localizedDescription
            }
        }
    }

    func manageSubscription() async {
        lastError = nil
        do {
            let url = try await DodoPaymentsService.getCustomerPortalURL()
            let session = DodoPaymentsSession()
            try await session.start(url: url)
            refreshSubscription()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func sendFeedback(
        message: String,
        email: String?,
        mayContact: Bool,
        screenshotPngBase64: String?,
        appVersion: String,
        osVersion: String
    ) async throws {
        Log.account.notice("feedback: \(message.prefix(100))")
    }

    private func refreshSubscription() {
        guard QwenAccountService.shared.mode == .backend,
              QwenAccountService.shared.sessionToken != nil else {
            _account = AccountUser(
                user: AccountUser.User(
                    firstName: nil,
                    email: nil,
                    image: nil,
                    cancelAtPeriodEnd: nil,
                    currentPeriodEnd: nil
                ),
                email: nil,
                name: nil,
                image: nil,
                tier: .none
            )
            _tier = .pro
            _availablePlans = [
                AvailablePlan(tier: .pro, monthlyPriceUsd: 29),
                AvailablePlan(tier: .max, monthlyPriceUsd: 99),
            ]
            return
        }

        Task {
            isLoading = true
            defer { isLoading = false }
            do {
                let info = try await DodoPaymentsService.getSubscriptionStatus()
                subscriptionInfo = info
                _tier = info.plan == "pro" || info.plan == "price_pro_monthly" ? .pro : .max
                _account = AccountUser(
                    user: AccountUser.User(
                        firstName: nil,
                        email: nil,
                        image: nil,
                        cancelAtPeriodEnd: nil,
                        currentPeriodEnd: info.expiresAt.map { DateFormatter().date(from: $0)?.timeIntervalSince1970 ?? 0 }
                    ),
                    email: nil,
                    name: nil,
                    image: nil,
                    tier: _tier
                )
                _availablePlans = [
                    AvailablePlan(tier: .pro, monthlyPriceUsd: 29),
                    AvailablePlan(tier: .max, monthlyPriceUsd: 99),
                ]
            } catch {
                lastError = error.localizedDescription
            }
        }
    }
}

// MARK: - Display helpers

extension AccountService {
    var displayPrimaryText: String {
        switch QwenAccountService.shared.mode {
        case .direct:
            QwenAccountService.shared.isConfigured ? "Direct Qwen API" : "Not configured"
        case .backend:
            QwenAccountService.shared.isConfigured ? "Filmidi Backend" : "Not configured"
        }
    }

    var displaySecondaryText: String? {
        switch QwenAccountService.shared.mode {
        case .direct:
            QwenAccountService.shared.qwenAPIKey.map { String($0.suffix(8)) }
        case .backend:
            QwenAccountService.shared.sessionEmail
        }
    }

    var displayInitial: String {
        displayPrimaryText.first.map { String($0).uppercased() } ?? ""
    }
}

// MARK: - Stub types (kept for compilation)

enum AccountTier: String, Decodable, Sendable {
    case none, pro, max
    var isPaid: Bool { self != .none }
    var planLabel: String {
        switch self {
        case .none: return "Free"
        case .pro: return "Pro plan"
        case .max: return "Max plan"
        }
    }
    var upgradeLabel: String {
        switch self {
        case .none: return ""
        case .pro: return "Pro"
        case .max: return "Max"
        }
    }
}

struct AccountUser: Decodable, Sendable {
    struct User: Decodable, Sendable {
        let firstName: String?
        let email: String?
        let image: String?
        let cancelAtPeriodEnd: Bool?
        let currentPeriodEnd: Double?
    }
    let user: User?
    let email: String?
    let name: String?
    let image: String?
    let tier: AccountTier
    var displayName: String? { name }
}

struct AvailablePlan: Decodable, Sendable, Identifiable {
    let tier: AccountTier
    let monthlyPriceUsd: Int
    var effectiveMonthlyPriceUsd: Int { monthlyPriceUsd }
    var hasDiscount: Bool { false }
    var monthlyBudgetCredits: Int? { nil }
    var id: String { tier.rawValue }
}

enum TopOffLimits {
    static let minDollars = 5
    static let maxDollars = 100
}
