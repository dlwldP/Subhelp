import Foundation
import Testing

/// 통계(MVP 2): 결제 캘린더, 비싼 구독 순위, 연간 결제 예고, 카테고리 합계
struct InsightCalculatorTests {
    let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return c
    }()

    var sut: InsightCalculator {
        InsightCalculator(billing: BillingCalculator(calendar: cal), cost: CostCalculator(usdToKrw: 1400))
    }

    func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d))!
    }

    func plan(_ price: Decimal, _ cycle: BillingCycle = .monthly, interval: Int = 1, currency: Currency = .krw,
              start: Date, trialEnd: Date? = nil) -> BillingPlan {
        BillingPlan(price: price, currency: currency, cycle: cycle, interval: interval,
                    startDate: start, trialEndDate: trialEnd)
    }

    // MARK: - 결제 캘린더

    @Test("월 결제 일정은 날짜순, 같은 날은 묶인다")
    func calendarPayments() {
        let plans = [
            plan(10_000, start: date(2026, 1, 15)),             // 10/15
            plan(3_000, .weekly, start: date(2026, 10, 1)),     // 10/1, 8, 15, 22, 29
            plan(120_000, .yearly, start: date(2025, 11, 2)),   // 10월 없음
        ]
        let month = date(2026, 10, 1)

        let payments = sut.payments(in: month, of: plans)
        #expect(payments.count == 6)
        #expect(payments.first == ScheduledPayment(planIndex: 1, date: date(2026, 10, 1)))

        let byDay = sut.paymentsByDay(in: month, of: plans)
        #expect(byDay[date(2026, 10, 15)]?.map(\.planIndex) == [0, 1])
        #expect(byDay[date(2026, 10, 2)] == nil)

        #expect(sut.total(of: payments, plans: plans) == 25_000)   // 10,000 + 3,000 × 5
    }

    @Test("체험 기간의 결제는 캘린더에 나오지 않는다")
    func calendarSkipsTrial() {
        let plans = [plan(5_000, .weekly, start: date(2026, 10, 1), trialEnd: date(2026, 10, 15))]
        let dates = sut.payments(in: date(2026, 10, 1), of: plans).map(\.date)
        #expect(dates == [date(2026, 10, 15), date(2026, 10, 22), date(2026, 10, 29)])
    }

    // MARK: - 비싼 구독 순위

    @Test("월 환산 기준 내림차순, 체험 중 제외, 상위 N개")
    func ranking() {
        let reference = date(2026, 10, 13)
        let plans = [
            plan(10_000, start: date(2026, 1, 1)),                                  // 10,000
            plan(240_000, .yearly, start: date(2026, 1, 1)),                        // 20,000
            plan(10, currency: .usd, start: date(2026, 1, 1)),                      // 14,000
            plan(99_000, start: date(2026, 10, 1), trialEnd: date(2026, 11, 1)),    // 체험 중
        ]

        let ranked = sut.ranking(of: plans, reference: reference)
        #expect(ranked.map(\.planIndex) == [1, 2, 0])
        #expect(ranked.first?.monthlyCost == 20_000)
        #expect(sut.ranking(of: plans, reference: reference, limit: 2).count == 2)
    }

    // MARK: - 연간 결제 예고

    @Test("30일 이내 연간 갱신만 고른다 (오늘·30일째 포함)")
    func upcomingRenewals() {
        let reference = date(2026, 10, 13)
        let plans = [
            plan(120_000, .yearly, start: date(2025, 10, 13)),           // 오늘 갱신
            plan(50_000, .yearly, start: date(2025, 11, 12)),            // 30일 후
            plan(80_000, .yearly, start: date(2025, 11, 13)),            // 31일 후 → 제외
            plan(10_000, start: date(2026, 1, 20)),                      // 월결제 → 제외
            plan(300_000, .monthly, interval: 12, start: date(2025, 10, 20)), // 12개월마다 → 포함
        ]

        let renewals = sut.upcomingRenewals(of: plans, reference: reference)
        #expect(renewals.map(\.planIndex) == [0, 4, 1])
    }

    // MARK: - 카테고리 합계

    @Test("카테고리별 월 환산 합계, 큰 순")
    func categoryTotals() {
        let reference = date(2026, 10, 13)
        let items: [(category: String, plan: BillingPlan)] = [
            ("영상", plan(17_000, start: date(2026, 1, 1))),
            ("영상", plan(13_000, start: date(2026, 1, 1))),
            ("음악", plan(10_900, start: date(2026, 1, 1))),
            ("AI", plan(20, currency: .usd, start: date(2026, 10, 1), trialEnd: date(2026, 11, 1))), // 체험 중
        ]

        let totals = sut.categoryTotals(of: items, reference: reference)
        #expect(totals == [CategoryTotal(category: "영상", monthlyCost: 30_000),
                           CategoryTotal(category: "음악", monthlyCost: 10_900)])
    }
}
