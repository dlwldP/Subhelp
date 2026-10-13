import StoreKit
import SwiftData
import SwiftUI
import UIKit
import UserNotifications

@main
struct SubhelpApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(SharedModelContainer.shared)
    }
}

/// 알림을 탭하면 해당 구독 상세로 이동, 앱 사용 중에도 배너 표시
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        guard let value = response.notification.request.content.userInfo["subscriptionID"] as? String,
              let id = UUID(uuidString: value)
        else { return }
        await MainActor.run { AppRouter.shared.open(subscriptionID: id) }
    }
}

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.requestReview) private var requestReview

    @AppStorage(AppSettings.Key.hasCompletedOnboarding, store: AppSettings.store)
    private var hasCompletedOnboarding = false
    @AppStorage(AppSettings.Key.hasRequestedReview, store: AppSettings.store)
    private var hasRequestedReview = false

    private let router = AppRouter.shared
    private let reviewThreshold = 3

    var body: some View {
        @Bindable var router = self.router

        TabView(selection: $router.selectedTab) {
            HomeView()
                .tabItem { Label("홈", systemImage: "house") }
                .tag(AppRouter.Tab.home)
            SubscriptionListView()
                .tabItem { Label("구독", systemImage: "list.bullet.rectangle") }
                .tag(AppRouter.Tab.subscriptions)
            StatsView()
                .tabItem { Label("통계", systemImage: "chart.pie") }
                .tag(AppRouter.Tab.stats)
            SettingsView()
                .tabItem { Label("설정", systemImage: "gearshape") }
                .tag(AppRouter.Tab.settings)
        }
        .sheet(isPresented: $router.isAddingSubscription, onDismiss: {
            Task { await router.offerNotificationPermissionIfNeeded() }
        }) {
            AddSubscriptionSheet()
        }
        .fullScreenCover(isPresented: Binding(get: { !hasCompletedOnboarding },
                                              set: { hasCompletedOnboarding = !$0 }),
                         onDismiss: {
            if router.shouldAddAfterOnboarding {
                router.shouldAddAfterOnboarding = false
                router.isAddingSubscription = true
            }
        }) {
            OnboardingView()
        }
        .alert("알림을 허용해주세요", isPresented: $router.isShowingPermissionPrompt) {
            Button("허용하기") {
                Task {
                    await NotificationService.shared.requestAuthorization()
                    await router.refreshNotificationStatus()
                    await SubscriptionSync.refresh(using: context)
                }
            }
            Button("나중에", role: .cancel) {}
        } message: {
            Text("결제일을 놓치지 않도록 미리 알려드릴게요. 알림을 허용해주세요.")
        }
        .onOpenURL { router.open($0) }
        .onChange(of: scenePhase) { _, phase in
            // 실행·포그라운드 복귀 시 알림 재예약 (지난 알림 소진, 시간대 변경 대응) + 날짜 변경 반영
            guard phase == .active else { return }
            Task {
                await router.refreshNotificationStatus()
                await SubscriptionSync.refresh(using: context)
            }
        }
        .task {
            // 첫 실행 시점에는 scenePhase 변경이 오지 않을 수 있어 직접 한 번 갱신한다
            await router.refreshNotificationStatus()
            await SubscriptionSync.refresh(using: context)
            await requestReviewIfNeeded()
        }
    }

    /// 구독을 3개 이상 등록한 뒤 앱을 다시 실행했을 때 한 번만 리뷰를 요청한다
    private func requestReviewIfNeeded() async {
        guard !hasRequestedReview,
              ((try? context.fetchCount(FetchDescriptor<Subscription>())) ?? 0) >= reviewThreshold
        else { return }
        try? await Task.sleep(for: .seconds(2))
        hasRequestedReview = true
        requestReview()
    }
}
