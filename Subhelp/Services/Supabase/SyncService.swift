import Foundation
import Supabase
import SwiftData

/// 기기(SwiftData) ↔ 서버(Supabase) 동기화 한 번 실행.
/// 구독 수가 많지 않으니 매번 서버의 내 구독 전체를 받아 `SyncPlanner` 규칙으로 병합한다.
@MainActor
enum SyncService {
    private static let table = "subscriptions"

    static func run(client: SupabaseClient, userID: UUID, context: ModelContext) async throws {
        let remoteRows: [RemoteSubscription] = try await client.from(table).select().execute().value
        let locals = try context.fetch(FetchDescriptor<Subscription>())
        let tombstones = try context.fetch(FetchDescriptor<DeletionTombstone>())

        let plan = SyncPlanner.plan(
            local: locals.map { SyncRecord(id: $0.id, updatedAt: $0.updatedAt) },
            remote: remoteRows.compactMap(\.syncRecord),
            tombstones: Set(tombstones.map(\.subscriptionID))
        )

        var localByID: [UUID: Subscription] = [:]
        for sub in locals { localByID[sub.id] = sub }
        var remoteByID: [UUID: RemoteSubscription] = [:]
        for row in remoteRows { remoteByID[row.id] = row }

        // 1. 이 기기에서 지운 것 → 서버에 삭제 표시
        let now = SupabaseDate.timestampString(.now)
        for id in plan.deleteRemote {
            try await client.from(table)
                .update(RemoteDeletion(deletedAt: now, updatedAt: now))
                .eq("id", value: id.uuidString)
                .execute()
        }

        // 2. 기기가 더 최신인 것 → 업로드
        let uploads = plan.push.compactMap { localByID[$0] }.map { RemoteSubscription($0, userID: userID) }
        if !uploads.isEmpty {
            try await client.from(table).upsert(uploads).execute()
        }

        // 3. 서버가 더 최신이거나 새로 생긴 것 → 기기에 반영
        for id in plan.apply {
            guard let row = remoteByID[id] else { continue }
            if let sub = localByID[id] {
                row.apply(to: sub)
            } else {
                context.insert(row.makeSubscription())
            }
        }

        // 4. 다른 기기에서 지운 것 → 기기에서도 삭제
        for id in plan.deleteLocal {
            if let sub = localByID[id] { context.delete(sub) }
        }

        // 5. 처리한 삭제 기록 정리
        for tombstone in tombstones where plan.clearTombstones.contains(tombstone.subscriptionID) {
            context.delete(tombstone)
        }

        try context.save()
    }
}
