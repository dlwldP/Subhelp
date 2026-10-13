import Foundation

/// 계산에 필요한 구독 정보만 담은 값 타입.
/// Domain 로직이 SwiftData(@Model)에 의존하지 않도록 이 타입으로 주고받는다.
struct BillingPlan: Hashable {
    var price: Decimal
    var currency: Currency
    var cycle: BillingCycle
    var interval: Int
    var startDate: Date
}
