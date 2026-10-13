import Foundation

/// `public.subscriptions` 행 (supabase/migrations/0001_init.sql)
struct RemoteSubscription: Codable, Sendable {
    let id: UUID
    let userID: UUID
    let name: String
    let price: Decimal
    let currencyCode: String
    let cycle: String
    let cycleInterval: Int
    let startDate: String
    let category: String
    let colorHex: String
    let notifyDaysBefore: Int?
    let isActive: Bool
    let trialEndDate: String?
    let memo: String
    let createdAt: String
    let updatedAt: String
    let deletedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case name, price
        case currencyCode = "currency_code"
        case cycle
        case cycleInterval = "cycle_interval"
        case startDate = "start_date"
        case category
        case colorHex = "color_hex"
        case notifyDaysBefore = "notify_days_before"
        case isActive = "is_active"
        case trialEndDate = "trial_end_date"
        case memo
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }

    /// 업로드용 — 기기의 구독을 서버 행으로
    init(_ sub: Subscription, userID: UUID) {
        id = sub.id
        self.userID = userID
        name = sub.name
        price = sub.price
        currencyCode = sub.currencyCode
        cycle = sub.cycleRaw
        cycleInterval = sub.cycleInterval
        startDate = SupabaseDate.dayString(sub.startDate)
        category = sub.category
        colorHex = sub.colorHex
        notifyDaysBefore = sub.notifyDaysBefore
        isActive = sub.isActive
        trialEndDate = sub.trialEndDate.map(SupabaseDate.dayString)
        memo = sub.memo
        createdAt = SupabaseDate.timestampString(sub.createdAt)
        updatedAt = SupabaseDate.timestampString(sub.updatedAt)
        deletedAt = nil
    }

    /// nil도 null로 보낸다. (기본 Codable은 nil 키를 빼버려서, upsert 시 "알림 끔" 같은 변경이 서버에 반영되지 않는다)
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(userID, forKey: .userID)
        try container.encode(name, forKey: .name)
        try container.encode(price, forKey: .price)
        try container.encode(currencyCode, forKey: .currencyCode)
        try container.encode(cycle, forKey: .cycle)
        try container.encode(cycleInterval, forKey: .cycleInterval)
        try container.encode(startDate, forKey: .startDate)
        try container.encode(category, forKey: .category)
        try container.encode(colorHex, forKey: .colorHex)
        try container.encode(notifyDaysBefore, forKey: .notifyDaysBefore)
        try container.encode(isActive, forKey: .isActive)
        try container.encode(trialEndDate, forKey: .trialEndDate)
        try container.encode(memo, forKey: .memo)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(deletedAt, forKey: .deletedAt)
    }

    var syncRecord: SyncRecord? {
        guard let updated = SupabaseDate.timestamp(from: updatedAt) else { return nil }
        return SyncRecord(id: id, updatedAt: updated, isDeleted: deletedAt != nil)
    }

    /// 서버 → 기기 반영. updatedAt은 서버 값을 그대로 써야 다음 동기화에서 "같음"으로 판단된다
    func apply(to sub: Subscription) {
        sub.name = name
        sub.price = Self.roundedPrice(price)
        sub.currencyCode = currencyCode
        sub.cycleRaw = cycle
        sub.cycleInterval = max(1, cycleInterval)
        if let start = SupabaseDate.day(from: startDate) { sub.startDate = start }
        sub.category = category
        sub.colorHex = colorHex
        sub.notifyDaysBefore = notifyDaysBefore
        sub.isActive = isActive
        sub.trialEndDate = trialEndDate.flatMap(SupabaseDate.day(from:))
        sub.memo = memo
        if let created = SupabaseDate.timestamp(from: createdAt) { sub.createdAt = created }
        if let updated = SupabaseDate.timestamp(from: updatedAt) { sub.updatedAt = updated }
    }

    func makeSubscription() -> Subscription {
        let sub = Subscription(name: name, price: price, cycle: BillingCycle(rawValue: cycle) ?? .monthly,
                               startDate: SupabaseDate.day(from: startDate) ?? .now)
        sub.id = id
        apply(to: sub)
        return sub
    }

    /// JSON 숫자 → Decimal 변환 시 생길 수 있는 오차(9.9900000001)를 소수 둘째 자리로 정리
    private static func roundedPrice(_ value: Decimal) -> Decimal {
        var input = value
        var result = Decimal()
        NSDecimalRound(&result, &input, 2, .plain)
        return result
    }
}

/// 이 기기에서 지운 구독을 서버에 삭제 표시
struct RemoteDeletion: Encodable, Sendable {
    let deletedAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case deletedAt = "deleted_at"
        case updatedAt = "updated_at"
    }
}

/// `public.presets` 행
struct RemotePreset: Decodable, Sendable {
    let name: String
    let category: String
    let cycle: String
    let colorHex: String

    enum CodingKeys: String, CodingKey {
        case name, category, cycle
        case colorHex = "color_hex"
    }

    var preset: SubscriptionPreset {
        SubscriptionPreset(
            name: name,
            category: SubscriptionCategory.all.contains(category) ? category : SubscriptionCategory.fallback,
            cycle: BillingCycle(rawValue: cycle) ?? .monthly,
            colorHex: colorHex
        )
    }
}
