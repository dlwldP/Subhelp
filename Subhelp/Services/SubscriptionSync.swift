import Foundation
import OSLog
import SwiftData
import WidgetKit

/// 데이터 변경과 그 뒤의 부수효과(저장 → 알림 재예약 → 위젯 갱신 → 서버 동기화)를 한곳에서 처리한다.
@MainActor
enum SubscriptionSync {
    /// 구독 삭제. 로그인 상태면 삭제 기록을 남겨 서버·다른 기기에도 전파한다
    static func delete(_ subscription: Subscription, in context: ModelContext) {
        if AccountService.shared.isSignedIn {
            context.insert(DeletionTombstone(subscriptionID: subscription.id))
        }
        context.delete(subscription)
    }

    static func setActive(_ isActive: Bool, for subscription: Subscription) {
        subscription.isActive = isActive
        subscription.touch()
    }

    /// 변경사항을 디스크에 저장하고 알림·위젯을 갱신한 뒤 서버 동기화를 예약한다.
    /// 위젯은 별도 프로세스라 저장(save)이 먼저 되어야 새 데이터를 읽는다.
    static func commit(_ context: ModelContext) async {
        do {
            try context.save()
        } catch {
            Logger.app.error("저장 실패: \(error.localizedDescription, privacy: .public)")
        }
        await refresh(using: context)
        AccountService.shared.requestSync()
    }

    static func refresh(using context: ModelContext) async {
        let all = (try? context.fetch(FetchDescriptor<Subscription>())) ?? []
        await NotificationService.shared.rescheduleAll(all)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
