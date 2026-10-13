import SwiftData
import SwiftUI

@main
struct SubTrackerApp: App {
    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
        .modelContainer(SharedModelContainer.shared)
    }
}

struct RootTabView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("홈", systemImage: "house") }
            SubscriptionListView()
                .tabItem { Label("구독", systemImage: "list.bullet.rectangle") }
            SettingsView()
                .tabItem { Label("설정", systemImage: "gearshape") }
        }
        .onChange(of: scenePhase) { _, phase in
            // 앱 실행·복귀 시 알림 재예약 (지난 알림이 소진됐을 수 있음) + 날짜 변경 반영
            guard phase == .active else { return }
            Task { await SubscriptionSync.refresh(using: context) }
        }
    }
}
