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
        plans.enumerated()
            .flatMap { index, plan in
                billing.paymentDates(in: month, plan).map { ScheduledPayment(planIndex: index, date: $0) }
            }
            .sorted { $0.date == $1.date ? $0.planIndex < $1.planIndex : $0.date < $1.date }
    }

    /// 날짜(자정 기준)별 결제 묶음
    func paymentsByDay(in month: Date, of plans: [BillingPlan]) -> [Date: [ScheduledPayment]] {
        Dictionary(grouping: payments(in: month, of: plans), by: \.date)
    }

    /// 해당 월 결제 예정 총액 (원화 환산)
    func total(of payments: [ScheduledPayment], plans: [BillingPlan]) -> Decimal {
        payments.reduce(Decimal(0)) { sum, payment in
            let plan = plans[payment.planIndex]
            return sum + cost.toKRW(plan.price, currency: plan.currency)
        }
    }

    /// 월 환산 금액이 큰 순 (체험 중 제외)
    func ranking(of plans: [BillingPlan], reference: Date = .now, limit: Int? = nil) -> [RankedPlan] {
        let ranked = plans.enumerated()
            .filter { !billing.isInTrial($0.element, on: reference) }
            .map { RankedPlan(planIndex: $0.offset, monthlyCost: cost.monthlyCost($0.element)) }
            .sorted { $0.monthlyCost == $1.monthlyCost ? $0.planIndex < $1.planIndex : $0.monthlyCost > $1.monthlyCost }
        guard let limit else { return ranked }
        return Array(ranked.prefix(limit))
    }

    /// 1년 이상 주기로 갱신되는 결제 중 `days`일 이내(오늘 포함) 예정인 것
    func upcomingRenewals(of plans: [BillingPlan], within days: Int = 30,
                          reference: Date = .now) -> [ScheduledPayment] {
        plans.enumerated()
            .filter { Self.isAnnual($0.element) }
            .compactMap { index, plan in
                let next = billing.nextPaymentDate(plan, from: reference)
                let remaining = billing.daysUntil(next, from: reference)
                return (0...days).contains(remaining) ? ScheduledPayment(planIndex: index, date: next) : nil
            }
            .sorted { $0.date < $1.date }
    }

    /// 카테고리별 월 환산 합계, 큰 순 (체험 중 제외)
    func categoryTotals(of items: [(category: String, plan: BillingPlan)], reference: Date = .now) -> [CategoryTotal] {
        var totals: [String: Decimal] = [:]
        for item in items where !billing.isInTrial(item.plan, on: reference) {
            totals[item.category, default: 0] += cost.monthlyCost(item.plan)
        }
        return totals
            .map { CategoryTotal(category: $0.key, monthlyCost: $0.value) }
            .sorted { $0.monthlyCost == $1.monthlyCost ? $0.category < $1.category : $0.monthlyCost > $1.monthlyCost }
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
