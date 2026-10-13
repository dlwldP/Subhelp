import Foundation
import SwiftData

/// 로그인 상태에서 지운 구독의 기록.
/// 다음 동기화 때 서버에 삭제 표시를 남겨 다른 기기에서도 지워지게 한 뒤 정리된다.
@Model
final class DeletionTombstone {
    var subscriptionID: UUID = UUID()
    var deletedAt: Date = Date.now

    init(subscriptionID: UUID) {
        self.subscriptionID = subscriptionID
    }
}
