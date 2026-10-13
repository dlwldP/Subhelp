import Foundation

/// 무료체험을 반영한 "실제 결제" 계산.
///
/// 규칙
/// - 체험 중 = 오늘이 체험 종료일 **이전**인 상태. 종료일 당일부터 유료로 본다
/// - 체험 종료일 이전의 결제일은 결제로 치지 않는다 (합계·알림·결제 횟수에서 제외)
extension BillingCalculator {
    func isInTrial(_ plan: BillingPlan, on reference: Date = .now) -> Bool {
        guard let trialEnd = plan.trialEndDate else { return false }
        return calendar.startOfDay(for: reference) < calendar.startOfDay(for: trialEnd)
    }

    /// reference(포함) 이후 첫 **유료** 결제일
    func nextPaymentDate(_ plan: BillingPlan, from reference: Date = .now) -> Date {
        var from = calendar.startOfDay(for: reference)
        if let trialEnd = plan.trialEndDate {
            from = max(from, calendar.startOfDay(for: trialEnd))
        }
        return nextBillingDate(start: plan.startDate, cycle: plan.cycle, interval: plan.interval, from: from)
    }

    /// 해당 월의 유료 결제일들
    func paymentDates(in month: Date, _ plan: BillingPlan) -> [Date] {
        billingDates(in: month, start: plan.startDate, cycle: plan.cycle, interval: plan.interval)
            .filter { isPaid($0, plan) }
    }

    /// 첫 결제일부터 reference(포함)까지 결제된 횟수 — "지금까지 낸 총액" 추정용
    func paidCount(_ plan: BillingPlan, through reference: Date = .now) -> Int {
        let first = calendar.startOfDay(for: plan.startDate)
        guard let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: reference)),
              end > first
        else { return 0 }
        return billingDates(in: DateInterval(start: first, end: end), start: plan.startDate,
                            cycle: plan.cycle, interval: plan.interval)
            .filter { isPaid($0, plan) }
            .count
    }

    private func isPaid(_ date: Date, _ plan: BillingPlan) -> Bool {
        guard let trialEnd = plan.trialEndDate else { return true }
        return date >= calendar.startOfDay(for: trialEnd)
    }
}
