import Foundation
import Testing

/// Domain 소스가 테스트 타깃에 직접 포함되므로 import 없이 사용한다. (project.yml 참고)
struct BillingCalculatorTests {
    let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return c
    }()

    var sut: BillingCalculator { BillingCalculator(calendar: cal) }

    func date(_ y: Int, _ m: Int, _ d: Int, hour: Int = 0) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: hour))!
    }

    // MARK: - nextBillingDate

    @Test("월말(31일) 시작은 2월엔 말일, 3월엔 다시 31일 — 날짜가 밀리지 않는다")
    func monthEndDoesNotDrift() {
        let start = date(2026, 1, 31)
        #expect(sut.nextBillingDate(start: start, cycle: .monthly, interval: 1, from: date(2026, 2, 1)) == date(2026, 2, 28))
        #expect(sut.nextBillingDate(start: start, cycle: .monthly, interval: 1, from: date(2026, 3, 1)) == date(2026, 3, 31))
        #expect(sut.nextBillingDate(start: start, cycle: .monthly, interval: 1, from: date(2026, 4, 1)) == date(2026, 4, 30))
        #expect(sut.nextBillingDate(start: start, cycle: .monthly, interval: 1, from: date(2026, 5, 1)) == date(2026, 5, 31))
    }

    @Test("윤년 2/29 시작 연결제 — 평년엔 2/28, 윤년엔 2/29")
    func leapDayYearly() {
        let start = date(2024, 2, 29)
        #expect(sut.nextBillingDate(start: start, cycle: .yearly, interval: 1, from: date(2025, 1, 1)) == date(2025, 2, 28))
        #expect(sut.nextBillingDate(start: start, cycle: .yearly, interval: 1, from: date(2027, 3, 1)) == date(2028, 2, 29))
    }

    @Test("오늘이 결제일이면 오늘을 반환한다 (시각 무관)")
    func todayIsBillingDay() {
        let start = date(2026, 1, 15)
        let reference = date(2026, 3, 15, hour: 22)
        let next = sut.nextBillingDate(start: start, cycle: .monthly, interval: 1, from: reference)
        #expect(next == date(2026, 3, 15))
        #expect(sut.daysUntil(next, from: reference) == 0)
    }

    @Test("시작일이 미래면 시작일이 다음 결제일")
    func futureStart() {
        let start = date(2026, 12, 1)
        let reference = date(2026, 10, 13)
        #expect(sut.nextBillingDate(start: start, cycle: .monthly, interval: 1, from: reference) == start)
        #expect(sut.daysUntil(start, from: reference) == 49)
    }

    @Test("3개월 간격 결제")
    func everyThreeMonths() {
        let start = date(2026, 1, 10)
        #expect(sut.nextBillingDate(start: start, cycle: .monthly, interval: 3, from: date(2026, 2, 1)) == date(2026, 4, 10))
        #expect(sut.nextBillingDate(start: start, cycle: .monthly, interval: 3, from: date(2026, 4, 11)) == date(2026, 7, 10))
    }

    @Test("격주 결제")
    func biweekly() {
        let start = date(2026, 10, 1)
        #expect(sut.nextBillingDate(start: start, cycle: .weekly, interval: 2, from: date(2026, 10, 2)) == date(2026, 10, 15))
    }

    @Test("시작일이 10년 전이어도 정확하다")
    func veryOldStart() {
        let start = date(2015, 1, 31)
        #expect(sut.nextBillingDate(start: start, cycle: .monthly, interval: 1, from: date(2026, 10, 13)) == date(2026, 10, 31))
        #expect(sut.nextBillingDate(start: date(2016, 3, 3), cycle: .weekly, interval: 1, from: date(2026, 10, 13))
                >= date(2026, 10, 13))
    }

    // MARK: - billingDates

    @Test("이번 달 결제 횟수 — 주결제는 4~5회")
    func weeklyCountInMonth() {
        let start = date(2026, 10, 1)
        #expect(sut.billingDates(in: date(2026, 10, 13), start: start, cycle: .weekly, interval: 1).count == 5)
        #expect(sut.billingDates(in: date(2026, 11, 13), start: start, cycle: .weekly, interval: 1).count == 4)
    }

    @Test("월말 시작 월결제는 2월에도 한 번 (2/28)")
    func monthEndInFebruary() {
        let dates = sut.billingDates(in: date(2026, 2, 10), start: date(2026, 1, 31), cycle: .monthly, interval: 1)
        #expect(dates == [date(2026, 2, 28)])
    }

    @Test("연결제는 결제 월에만 포함된다")
    func yearlyOnlyInBillingMonth() {
        let start = date(2025, 10, 5)
        #expect(sut.billingDates(in: date(2026, 10, 1), start: start, cycle: .yearly, interval: 1) == [date(2026, 10, 5)])
        #expect(sut.billingDates(in: date(2026, 11, 1), start: start, cycle: .yearly, interval: 1).isEmpty)
    }

    @Test("시작일 이전 달에는 결제가 없다")
    func noBillingBeforeStart() {
        #expect(sut.billingDates(in: date(2026, 9, 1), start: date(2026, 10, 1), cycle: .monthly, interval: 1).isEmpty)
    }
}
