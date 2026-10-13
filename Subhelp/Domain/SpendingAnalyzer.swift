import Foundation

/// 홈·위젯에 보여줄 지출 요약.
///
/// - `monthTotal`: 이번 달에 **실제로** 결제되는 금액 (연결제가 있는 달은 튄다)
/// - `monthlyAverage`: 모든 구독을 월 단위로 **환산한 평균**
/// - 체험 중인 구독은 월·연 환산에서 빠지고, 결제 예정액에는 체험 종료일 이후 결제만 들어간다
struct SpendingSummary: Equatable {
    var monthTotal: Decimal = 0
    var paymentCount: Int = 0
    var remainingTotal: Decimal = 0
    var remainingCount: Int = 0
    var monthlyAverage: Decimal = 0
    var yearlyTotal: Decimal = 0
    /// 달러 등 환율 환산 금액이 섞여 있으면 true → 금액 앞에 "≈" 표시
    var isEstimated: Bool = false
}

struct SpendingAnalyzer {
    var billing: BillingCalculator
    var cost: CostCalculator

    func summary(of plans: [BillingPlan], reference: Date = .now) -> SpendingSummary {
        let today = billing.calendar.startOfDay(for: reference)
        var summary = SpendingSummary()

        for plan in plans {
            let krw = cost.toKRW(plan.price, currency: plan.currency)
            let dates = billing.paymentDates(in: reference, plan)
            let remaining = dates.filter { $0 >= today }.count
            let inTrial = billing.isInTrial(plan, on: reference)

            summary.monthTotal += krw * Decimal(dates.count)
            summary.paymentCount += dates.count
            summary.remainingTotal += krw * Decimal(remaining)
            summary.remainingCount += remaining
            if !inTrial {
                summary.monthlyAverage += cost.monthlyCost(plan)
            }
            if plan.currency != .krw && (!dates.isEmpty || !inTrial) {
                summary.isEstimated = true
            }
        }
        summary.yearlyTotal = summary.monthlyAverage * 12
        return summary
    }
}
