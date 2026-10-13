import Foundation

/// 홈·위젯에 보여줄 지출 요약.
///
/// - `monthTotal`: 이번 달에 **실제로** 결제되는 금액 (연결제가 있는 달은 튄다)
/// - `monthlyAverage`: 모든 구독을 월 단위로 **환산한 평균**
struct SpendingSummary: Equatable {
    var monthTotal: Decimal = 0
    var paymentCount: Int = 0
    var remainingTotal: Decimal = 0
    var remainingCount: Int = 0
    var monthlyAverage: Decimal = 0
    var yearlyTotal: Decimal = 0
}

struct SpendingAnalyzer {
    var billing: BillingCalculator
    var cost: CostCalculator

    func summary(of plans: [BillingPlan], reference: Date = .now) -> SpendingSummary {
        let today = billing.calendar.startOfDay(for: reference)
        var summary = SpendingSummary()

        for plan in plans {
            let krw = cost.toKRW(plan.price, currency: plan.currency)
            let dates = billing.billingDates(in: reference, start: plan.startDate,
                                             cycle: plan.cycle, interval: plan.interval)
            let remaining = dates.filter { $0 >= today }.count

            summary.monthTotal += krw * Decimal(dates.count)
            summary.paymentCount += dates.count
            summary.remainingTotal += krw * Decimal(remaining)
            summary.remainingCount += remaining
            summary.yearlyTotal += cost.yearlyCost(plan)
        }
        summary.monthlyAverage = summary.yearlyTotal / 12
        return summary
    }
}
