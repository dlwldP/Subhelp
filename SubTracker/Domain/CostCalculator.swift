import Foundation

/// 금액 환산. 부동소수 오차를 피하려고 전부 Decimal로 계산한다.
struct CostCalculator {
    var usdToKrw: Decimal

    func toKRW(_ price: Decimal, currency: Currency) -> Decimal {
        currency == .usd ? price * usdToKrw : price
    }

    /// 연 환산 금액 (주결제는 1년 = 52주)
    func yearlyCost(price: Decimal, currency: Currency, cycle: BillingCycle, interval: Int) -> Decimal {
        let krw = toKRW(price, currency: currency)
        let interval = Decimal(max(1, interval))
        switch cycle {
        case .weekly:  return krw * 52 / interval
        case .monthly: return krw * 12 / interval
        case .yearly:  return krw / interval
        }
    }

    /// 월 환산 금액 (비교·정렬용 평균값)
    func monthlyCost(price: Decimal, currency: Currency, cycle: BillingCycle, interval: Int) -> Decimal {
        yearlyCost(price: price, currency: currency, cycle: cycle, interval: interval) / 12
    }

    func yearlyCost(_ plan: BillingPlan) -> Decimal {
        yearlyCost(price: plan.price, currency: plan.currency, cycle: plan.cycle, interval: plan.interval)
    }

    func monthlyCost(_ plan: BillingPlan) -> Decimal {
        monthlyCost(price: plan.price, currency: plan.currency, cycle: plan.cycle, interval: plan.interval)
    }
}
