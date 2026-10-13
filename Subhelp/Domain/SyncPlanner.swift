import Foundation

/// 동기화 비교에 필요한 최소 정보 (기기·서버 공통)
struct SyncRecord: Hashable {
    let id: UUID
    let updatedAt: Date
    var isDeleted: Bool = false
}

/// 이번 동기화에서 할 일
struct SyncPlan: Equatable {
    /// 기기 → 서버 업로드 (추가·수정)
    var push: Set<UUID> = []
    /// 서버 → 기기 반영 (추가·수정)
    var apply: Set<UUID> = []
    /// 다른 기기에서 삭제돼 이 기기에서도 지울 것
    var deleteLocal: Set<UUID> = []
    /// 이 기기에서 삭제해 서버에도 삭제 표시할 것
    var deleteRemote: Set<UUID> = []
    /// 처리가 끝나 지워도 되는 삭제 기록
    var clearTombstones: Set<UUID> = []
}

/// 기기 ↔ 서버 병합 규칙 (마지막 수정 우선, Last-Write-Wins)
///
/// - 기기에만 있음 → 업로드
/// - 서버에만 있음 → 기기에 추가 (서버에서 삭제된 건 무시)
/// - 둘 다 있음 → `updatedAt`이 더 최근인 쪽으로 맞춘다 (1ms 이내 차이는 같은 것으로 본다)
/// - 삭제는 수정보다 우선한다: 서버에 삭제 표시가 있으면 기기에서도 지운다
/// - 이 기기에서 지운 구독(삭제 기록)은 서버에 삭제 표시를 남기고 기록을 정리한다
enum SyncPlanner {
    static let tolerance: TimeInterval = 0.001

    static func plan(local: [SyncRecord], remote: [SyncRecord], tombstones: Set<UUID>) -> SyncPlan {
        var plan = SyncPlan()
        var remoteByID: [UUID: SyncRecord] = [:]
        for record in remote { remoteByID[record.id] = record }

        for id in tombstones {
            if let record = remoteByID[id], !record.isDeleted {
                plan.deleteRemote.insert(id)
            }
            plan.clearTombstones.insert(id)
        }

        var localIDs: Set<UUID> = []
        for record in local where !tombstones.contains(record.id) {
            localIDs.insert(record.id)
            guard let other = remoteByID[record.id] else {
                plan.push.insert(record.id)
                continue
            }
            if other.isDeleted {
                plan.deleteLocal.insert(record.id)
                continue
            }
            let difference = record.updatedAt.timeIntervalSince(other.updatedAt)
            if difference > tolerance {
                plan.push.insert(record.id)
            } else if difference < -tolerance {
                plan.apply.insert(record.id)
            }
        }

        for record in remote where !record.isDeleted && !localIDs.contains(record.id) && !tombstones.contains(record.id) {
            plan.apply.insert(record.id)
        }
        return plan
    }
}

extension Date {
    /// 서버(timestamptz)에 저장되는 밀리초 단위로 자른다.
    /// 그대로 두면 마이크로초 차이 때문에 매번 "기기가 더 최신"으로 판단돼 업로드가 반복된다.
    var truncatedToMilliseconds: Date {
        Date(timeIntervalSince1970: (timeIntervalSince1970 * 1000).rounded(.down) / 1000)
    }
}
