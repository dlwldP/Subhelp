import Foundation
import Testing

/// 기기 ↔ 서버 동기화 병합 규칙
struct SyncPlannerTests {
    let base = Date(timeIntervalSince1970: 1_800_000_000)
    let a = UUID(), b = UUID(), c = UUID()

    func at(_ seconds: TimeInterval) -> Date { base.addingTimeInterval(seconds) }

    @Test("기기에만 있으면 업로드, 서버에만 있으면 기기에 추가")
    func oneSided() {
        let plan = SyncPlanner.plan(local: [SyncRecord(id: a, updatedAt: at(0))],
                                    remote: [SyncRecord(id: b, updatedAt: at(0))],
                                    tombstones: [])
        #expect(plan == SyncPlan(push: [a], apply: [b]))
    }

    @Test("둘 다 있으면 더 최근에 수정된 쪽이 이긴다")
    func lastWriteWins() {
        let plan = SyncPlanner.plan(
            local: [SyncRecord(id: a, updatedAt: at(10)), SyncRecord(id: b, updatedAt: at(0))],
            remote: [SyncRecord(id: a, updatedAt: at(0)), SyncRecord(id: b, updatedAt: at(10))],
            tombstones: [])
        #expect(plan == SyncPlan(push: [a], apply: [b]))
    }

    @Test("1ms 이내 차이는 같은 것으로 보고 아무것도 하지 않는다")
    func withinTolerance() {
        let plan = SyncPlanner.plan(local: [SyncRecord(id: a, updatedAt: at(0.0004))],
                                    remote: [SyncRecord(id: a, updatedAt: at(0))],
                                    tombstones: [])
        #expect(plan == SyncPlan())
    }

    @Test("서버에서 삭제된 구독은 기기에서도 지운다 (기기 쪽이 더 최근이어도 삭제 우선)")
    func remoteDeletionWins() {
        let plan = SyncPlanner.plan(local: [SyncRecord(id: a, updatedAt: at(100))],
                                    remote: [SyncRecord(id: a, updatedAt: at(0), isDeleted: true),
                                             SyncRecord(id: b, updatedAt: at(0), isDeleted: true)],
                                    tombstones: [])
        #expect(plan == SyncPlan(deleteLocal: [a]))   // b는 기기에 없으니 무시
    }

    @Test("이 기기에서 지운 구독은 서버에 삭제 표시하고 기록을 정리한다")
    func localTombstone() {
        let plan = SyncPlanner.plan(local: [],
                                    remote: [SyncRecord(id: a, updatedAt: at(0)),
                                             SyncRecord(id: b, updatedAt: at(0), isDeleted: true)],
                                    tombstones: [a, b, c])
        // a: 서버에 살아 있으니 삭제 표시 / b: 이미 삭제됨 / c: 서버에 올라간 적 없음 → 모두 기록만 정리
        #expect(plan == SyncPlan(deleteRemote: [a], clearTombstones: [a, b, c]))
    }

    @Test("밀리초 단위 자르기")
    func truncation() {
        let date = Date(timeIntervalSince1970: 1_800_000_000.123_789)
        #expect(abs(date.truncatedToMilliseconds.timeIntervalSince1970 - 1_800_000_000.123) < 0.000_001)
    }
}
