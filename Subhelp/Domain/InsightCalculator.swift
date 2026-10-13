import Foundation

/// 결제 일정 한 건 — `planIndex`는 입력 배열의 인덱스 (모델 타입과 분리하기 위해 인덱스로 돌려준다)
struct ScheduledPayment: Hashable {
    let planIndex: Int
    let date: Date
}

/// 월 환산 금액 순위 한 건
struct RankedPlan: Hashable {
    let planIndex: Int
    let monthlyCost: Decimal
}

/// 카테고리별 월 환산 합계
struct CategoryTotal: Hashable, Identifiable {
    let category: String
    let monthlyCost: Decimal
    var id: String { category }
}

/// 통계(MVP 2) 계산 — 결제 캘린더, 비싼 구독 순위, 연간 결제 예고, 카테고리 합계.
/// 체험 중인 구독은 순위·카테고리 합계에서 빠지고, 캘린더·예고에는 체험 종료 후 결제만 들어간다.
struct InsightCalculator {
    var billing: BillingCalculator
    var cost: CostCalculator

    /// 해당 월의 모든 유료 결제 (날짜순)
    func payments(in month: Date, of plans: [BillingPlan]) -> [ScheduledPayment] {
        var result: [ScheduledPayment] = []
        for (index, plan) in plans.enumerated() {
            for date in billing.paymentDates(in: month, plan) {
                result.append(ScheduledPayment(planIndex: index, date: date))
            }
        }
        result.sort { (lhs: ScheduledPayment, rhs: ScheduledPayment) -> Bool in
            if lhs.date != rhs.date { return lhs.date < rhs.date }
            return lhs.planIndex < rhs.planIndex
        }
        return result
    }

    /// 날짜(자정 기준)별 결제 묶음
    func paymentsByDay(in month: Date, of plans: [BillingPlan]) -> [Date: [ScheduledPayment]] {
        Dictionary(grouping: payments(in: month, of: plans), by: \.date)
    }

    /// 해당 월 결제 예정 총액 (원화 환산)
    func total(of payments: [ScheduledPayment], plans: [BillingPlan]) -> Decimal {
        var sum: Decimal = 0
        for payment in payments {
            let plan = plans[payment.planIndex]
            sum += cost.toKRW(plan.price, currency: plan.currency)
        }
        return sum
    }

    /// 월 환산 금액이 큰 순 (체험 중 제외)
    func ranking(of plans: [BillingPlan], reference: Date = .now, limit: Int? = nil) -> [RankedPlan] {
        var ranked: [RankedPlan] = []
        for (index, plan) in plans.enumerated() where !billing.isInTrial(plan, on: reference) {
            ranked.append(RankedPlan(planIndex: index, monthlyCost: cost.monthlyCost(plan)))
        }
        ranked.sort { (lhs: RankedPlan, rhs: RankedPlan) -> Bool in
            if lhs.monthlyCost != rhs.monthlyCost { return lhs.monthlyCost > rhs.monthlyCost }
            return lhs.planIndex < rhs.planIndex
        }
        guard let limit else { return ranked }
        return Array(ranked.prefix(limit))
    }

    /// 1년 이상 주기로 갱신되는 결제 중 `days`일 이내(오늘 포함) 예정인 것
    func upcomingRenewals(of plans: [BillingPlan], within days: Int = 30,
                          reference: Date = .now) -> [ScheduledPayment] {
        var result: [ScheduledPayment] = []
        for (index, plan) in plans.enumerated() where Self.isAnnual(plan) {
            let next = billing.nextPaymentDate(plan, from: reference)
            let remaining = billing.daysUntil(next, from: reference)
            if (0...days).contains(remaining) {
                result.append(ScheduledPayment(planIndex: index, date: next))
            }
        }
        result.sort { (lhs: ScheduledPayment, rhs: ScheduledPayment) -> Bool in lhs.date < rhs.date }
        return result
    }

    /// 카테고리별 월 환산 합계, 큰 순 (체험 중 제외)
    func categoryTotals(of items: [(category: String, plan: BillingPlan)], reference: Date = .now) -> [CategoryTotal] {
        var totals: [String: Decimal] = [:]
        for item in items where !billing.isInTrial(item.plan, on: reference) {
            totals[item.category, default: 0] += cost.monthlyCost(item.plan)
        }
        var result: [CategoryTotal] = totals.map { CategoryTotal(category: $0.key, monthlyCost: $0.value) }
        result.sort { (lhs: CategoryTotal, rhs: CategoryTotal) -> Bool in
            if lhs.monthlyCost != rhs.monthlyCost { return lhs.monthlyCost > rhs.monthlyCost }
            return lhs.category < rhs.category
        }
        return result
    }

    /// 연결제, 또는 12개월 이상 간격의 월결제
    static func isAnnual(_ plan: BillingPlan) -> Bool {
        switch plan.cycle {
        case .yearly:  true
        case .monthly: plan.interval >= 12
        case .weekly:  plan.interval >= 52
        }
    }
}

/// 구독 목록 정렬 (I-05)
enum SubscriptionSortOrder: String, CaseIterable, Identifiable {
    case nextPayment
    case amount
    case name

    var id: String { rawValue }

    var title: String {
        switch self {
        case .nextPayment: "결제일순"
        case .amount:      "금액순"
        case .name:        "이름순"
        }
    }
}
