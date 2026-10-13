import Foundation
import OSLog
import SwiftData
import WidgetKit

/// 데이터가 바뀐 뒤의 부수효과(저장 → 알림 재예약 → 위젯 갱신)를 한곳에서 처리한다.
@MainActor
enum SubscriptionSync {
    /// 변경사항을 디스크에 저장하고 알림·위젯을 갱신한다.
    /// 위젯은 별도 프로세스라 저장(save)이 먼저 되어야 새 데이터를 읽는다.
    static func commit(_ context: ModelContext) async {
        do {
            try context.save()
        } catch {
            Logger.app.error("저장 실패: \(error.localizedDescription, privacy: .public)")
        }
        await refresh(using: context)
    }

    static func refresh(using context: ModelContext) async {
        let all = (try? context.fetch(FetchDescriptor<Subscription>())) ?? []
        await NotificationService.shared.rescheduleAll(all)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
