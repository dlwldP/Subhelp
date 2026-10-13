import Foundation
import Testing

struct CostCalculatorTests {
    let sut = CostCalculator(usdToKrw: 1400)

    @Test("연결제의 월 환산")
    func yearlyToMonthly() {
        #expect(sut.monthlyCost(price: 120_000, currency: .krw, cycle: .yearly, interval: 1) == 10_000)
    }

    @Test("주결제의 월 환산 (52주 / 12개월)")
    func weeklyToMonthly() {
        #expect(sut.monthlyCost(price: 12_000, currency: .krw, cycle: .weekly, interval: 1) == 52_000)
    }

    @Test("3개월 간격 결제의 월 환산")
    func quarterlyToMonthly() {
        #expect(sut.monthlyCost(price: 30_000, currency: .krw, cycle: .monthly, interval: 3) == 10_000)
    }

    @Test("USD는 입력한 환율로 원화 환산")
    func usdConversion() {
        #expect(sut.toKRW(10, currency: .usd) == 14_000)
        // Decimal 부동소수 리터럴은 Double을 거쳐 오차가 생기므로 문자열로 만든다
        #expect(sut.toKRW(Decimal(string: "9.99")!, currency: .usd) == 13_986)
        #expect(sut.monthlyCost(price: 10, currency: .usd, cycle: .monthly, interval: 1) == 14_000)
    }
}

struct SpendingAnalyzerTests {
    let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return c
    }()

    func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d))!
    }

    @Test("이번 달 실제 지출과 월 환산 평균은 다르다")
    func actualVersusAverage() {
        let sut = SpendingAnalyzer(billing: BillingCalculator(calendar: cal), cost: CostCalculator(usdToKrw: 1400))
        let plans = [
            BillingPlan(price: 10_000, currency: .krw, cycle: .monthly, interval: 1, startDate: date(2026, 1, 15)),
            BillingPlan(price: 120_000, currency: .krw, cycle: .yearly, interval: 1, startDate: date(2025, 10, 5)),
            BillingPlan(price: 10, currency: .usd, cycle: .monthly, interval: 1, startDate: date(2026, 1, 1)),
        ]

        let summary = sut.summary(of: plans, reference: date(2026, 10, 13))

        #expect(summary.monthTotal == 144_000)      // 10,000 + 120,000 + 14,000
        #expect(summary.paymentCount == 3)
        #expect(summary.remainingCount == 1)        // 10/15만 남음
        #expect(summary.remainingTotal == 10_000)
        #expect(summary.yearlyTotal == 408_000)     // 120,000 + 120,000 + 168,000
        #expect(summary.monthlyAverage == 34_000)
    }

    @Test("구독이 없으면 모두 0")
    func empty() {
        let sut = SpendingAnalyzer(billing: BillingCalculator(calendar: cal), cost: CostCalculator(usdToKrw: 1400))
        #expect(sut.summary(of: []) == SpendingSummary())
    }
}
