import Foundation
import Testing

/// 무료체험 반영, 지금까지 낸 횟수, 금액 입력 규칙
struct TrialAndPaymentTests {
    let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return c
    }()

    var billing: BillingCalculator { BillingCalculator(calendar: cal) }

    func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d))!
    }

    func plan(price: Decimal = 10_000, currency: Currency = .krw, cycle: BillingCycle = .monthly,
              interval: Int = 1, start: Date, trialEnd: Date? = nil) -> BillingPlan {
        BillingPlan(price: price, currency: currency, cycle: cycle, interval: interval,
                    startDate: start, trialEndDate: trialEnd)
    }

    // MARK: - 체험 중 판단

    @Test("체험 종료일 전날까지는 체험 중, 종료일 당일부터 유료")
    func trialBoundary() {
        let p = plan(start: date(2026, 10, 1), trialEnd: date(2026, 10, 20))
        #expect(billing.isInTrial(p, on: date(2026, 10, 19)))
        #expect(!billing.isInTrial(p, on: date(2026, 10, 20)))
        #expect(!billing.isInTrial(plan(start: date(2026, 10, 1)), on: date(2026, 10, 19)))
    }

    // MARK: - 다음 유료 결제일

    @Test("체험 중이면 다음 결제일은 체험 종료일 이후 첫 결제일")
    func nextPaymentSkipsTrial() {
        // 매월 5일 결제, 체험은 10/20까지 → 다음 유료 결제는 11/5
        let p = plan(start: date(2026, 9, 5), trialEnd: date(2026, 10, 20))
        #expect(billing.nextPaymentDate(p, from: date(2026, 10, 1)) == date(2026, 11, 5))
    }

    @Test("첫 결제일 = 체험 종료일이면 그날이 첫 결제")
    func firstPaymentOnTrialEnd() {
        let p = plan(start: date(2026, 10, 20), trialEnd: date(2026, 10, 20))
        #expect(billing.nextPaymentDate(p, from: date(2026, 10, 13)) == date(2026, 10, 20))
    }

    @Test("체험이 끝난 뒤에는 일반 구독과 같다")
    func afterTrial() {
        let p = plan(start: date(2026, 1, 20), trialEnd: date(2026, 1, 20))
        #expect(billing.nextPaymentDate(p, from: date(2026, 10, 13)) == date(2026, 10, 20))
    }

    // MARK: - 결제 예정액

    @Test("체험 중 구독은 결제 예정액·월 환산에서 빠지고, 이번 달 체험 종료 후 결제는 포함")
    func trialInSummary() {
        let sut = SpendingAnalyzer(billing: billing, cost: CostCalculator(usdToKrw: 1400))
        let reference = date(2026, 10, 13)
        let plans = [
            // 일반 구독: 10/15 결제
            plan(price: 10_000, start: date(2026, 1, 15)),
            // 체험 중, 이번 달 10/25 종료 → 10/25 결제는 포함
            plan(price: 5_000, start: date(2026, 10, 25), trialEnd: date(2026, 10, 25)),
            // 체험 중, 다음 달 종료 → 이번 달 결제 없음
            plan(price: 7_000, start: date(2026, 9, 1), trialEnd: date(2026, 11, 10)),
        ]

        let summary = sut.summary(of: plans, reference: reference)

        #expect(summary.monthTotal == 15_000)
        #expect(summary.remainingCount == 2)
        #expect(summary.monthlyAverage == 10_000)   // 체험 중 구독 제외
        #expect(summary.yearlyTotal == 120_000)
        #expect(!summary.isEstimated)
    }

    @Test("달러 구독이 합계에 들어가면 추정치(≈)로 표시")
    func estimatedWhenUSD() {
        let sut = SpendingAnalyzer(billing: billing, cost: CostCalculator(usdToKrw: 1400))
        let summary = sut.summary(of: [plan(price: 10, currency: .usd, start: date(2026, 1, 1))],
                                  reference: date(2026, 10, 13))
        #expect(summary.isEstimated)
        #expect(summary.monthTotal == 14_000)
    }

    // MARK: - 지금까지 낸 횟수

    @Test("첫 결제일부터 오늘(포함)까지 결제 횟수")
    func paidCount() {
        let p = plan(start: date(2026, 1, 15))
        #expect(billing.paidCount(p, through: date(2026, 10, 14)) == 9)   // 1/15 ~ 9/15
        #expect(billing.paidCount(p, through: date(2026, 10, 15)) == 10)  // 오늘 결제 포함
    }

    @Test("첫 결제일이 미래면 0회, 체험 기간 결제는 세지 않는다")
    func paidCountEdgeCases() {
        #expect(billing.paidCount(plan(start: date(2026, 12, 1)), through: date(2026, 10, 13)) == 0)
        let trial = plan(start: date(2026, 8, 1), trialEnd: date(2026, 9, 1))
        #expect(billing.paidCount(trial, through: date(2026, 10, 13)) == 2)  // 9/1, 10/1
    }

    @Test("시작일이 수년 전인 주결제도 계산된다")
    func paidCountOldWeekly() {
        let p = plan(cycle: .weekly, start: date(2016, 1, 1))
        #expect(billing.paidCount(p, through: date(2016, 1, 29)) == 5)
        #expect(billing.paidCount(p, through: date(2026, 10, 13)) > 500)
    }

    // MARK: - 금액 입력 규칙

    @Test("0원·음수는 불가, 9자리까지 허용")
    func priceRule() {
        #expect(PriceRule.validate(0) == .notPositive)
        #expect(PriceRule.validate(-100) == .notPositive)
        #expect(PriceRule.validate(999_999_999) == nil)
        #expect(PriceRule.validate(1_000_000_000) == .tooLarge)
        #expect(PriceRule.validate(Decimal(string: "9.99")!) == nil)
    }
}
