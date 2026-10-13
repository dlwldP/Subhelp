import Foundation

/// 계산에 필요한 구독 정보만 담은 값 타입.
/// Domain 로직이 SwiftData(@Model)에 의존하지 않도록 이 타입으로 주고받는다.
struct BillingPlan: Hashable {
    var price: Decimal
    var currency: Currency
    var cycle: BillingCycle
    var interval: Int
    var startDate: Date
    /// 무료체험 종료일. 이 날짜 이전의 결제일은 결제로 치지 않는다 (종료일 당일부터 유료)
    var trialEndDate: Date? = nil
}
