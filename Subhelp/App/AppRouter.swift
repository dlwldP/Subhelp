import Foundation
import Observation
import UserNotifications

/// 앱 전역 화면 상태 — 탭 선택, 구독 추가 시트, 딥링크, 알림 권한 상태
@MainActor
@Observable
final class AppRouter {
    static let shared = AppRouter()

    enum Tab: Hashable {
        case home, subscriptions, settings
    }

    var selectedTab: Tab = .home
    var homePath: [UUID] = []
    var subscriptionsPath: [UUID] = []

    /// [+] 구독 추가 — 모든 탭에서 같은 시트를 띄운다
    var isAddingSubscription = false
    /// 첫 구독 저장 직후, 시트가 닫히면 알림 권한 안내를 띄운다
    var shouldOfferNotificationPermission = false
    var isShowingPermissionPrompt = false
    /// 온보딩이 닫힌 뒤 구독 추가 시트를 연다
    var shouldAddAfterOnboarding = false

    private(set) var notificationStatus: UNAuthorizationStatus = .notDetermined

    var isNotificationDenied: Bool { notificationStatus == .denied }

    private init() {}

    func open(_ url: URL) {
        switch DeepLink.parse(url) {
        case .subscription(let id): open(subscriptionID: id)
        case .home: selectedTab = .home
        case nil: break
        }
    }

    func open(subscriptionID: UUID) {
        isAddingSubscription = false
        selectedTab = .subscriptions
        subscriptionsPath = [subscriptionID]
    }

    func refreshNotificationStatus() async {
        notificationStatus = await NotificationService.shared.authorizationStatus()
    }

    /// 구독 추가 시트가 닫힌 뒤 호출 — 권한을 아직 묻지 않았으면 안내 알럿을 띄운다
    func offerNotificationPermissionIfNeeded() async {
        guard shouldOfferNotificationPermission else { return }
        shouldOfferNotificationPermission = false
        await refreshNotificationStatus()
        if notificationStatus == .notDetermined {
            isShowingPermissionPrompt = true
        }
    }
}
