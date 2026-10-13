import Foundation

/// 결제일 계산.
///
/// "이전 결제일 + 1개월"을 반복하면 1/31 → 2/28 → 3/28 … 처럼 날짜가 밀린다.
/// 그래서 항상 **최초 결제일 + n번째 주기**로 계산한다.
/// Calendar를 주입받아 타임존과 무관하게 테스트할 수 있다.
struct BillingCalculator {
    var calendar: Calendar = .current

    /// 비정상 입력에 대한 무한 루프 방지 상한
    private let maxOccurrences = 10_000

    /// 최초 결제일 기준 n번째 결제일 (n = 0이면 최초 결제일)
    func occurrence(_ n: Int, start: Date, cycle: BillingCycle, interval: Int) -> Date? {
        calendar.date(byAdding: cycle.component,
                      value: max(1, interval) * n,
                      to: calendar.startOfDay(for: start))
    }

    /// reference 날짜(포함) 이후 첫 결제일
    func nextBillingDate(start: Date, cycle: BillingCycle, interval: Int,
                         from reference: Date = .now) -> Date {
        let first = calendar.startOfDay(for: start)
        let today = calendar.startOfDay(for: reference)
        if first >= today { return first }

        var n = skipCount(start: first, target: today, cycle: cycle, interval: interval)
        while n < maxOccurrences,
              let date = occurrence(n, start: first, cycle: cycle, interval: interval) {
            if date >= today { return date }
            n += 1
        }
        return first
    }

    /// 특정 월에 포함되는 결제일들 (이번 달 실제 지출 계산용)
    func billingDates(in month: Date, start: Date, cycle: BillingCycle, interval: Int) -> [Date] {
        guard let range = calendar.dateInterval(of: .month, for: month) else { return [] }
        return billingDates(in: range, start: start, cycle: cycle, interval: interval)
    }

    /// 구간 [range.start, range.end)에 포함되는 결제일들
    func billingDates(in range: DateInterval, start: Date, cycle: BillingCycle, interval: Int) -> [Date] {
        let first = calendar.startOfDay(for: start)
        var result: [Date] = []
        var n = skipCount(start: first, target: range.start, cycle: cycle, interval: interval)
        while n < maxOccurrences,
              let date = occurrence(n, start: first, cycle: cycle, interval: interval),
              date < range.end {
            if date >= range.start { result.append(date) }
            n += 1
        }
        return result
    }

    func daysUntil(_ date: Date, from reference: Date = .now) -> Int {
        calendar.dateComponents([.day],
                                from: calendar.startOfDay(for: reference),
                                to: calendar.startOfDay(for: date)).day ?? 0
    }

    /// target보다 확실히 앞선 회차까지 건너뛴다.
    /// 시작일이 수년 전이어도 루프가 몇 번 안에 끝난다.
    private func skipCount(start: Date, target: Date, cycle: BillingCycle, interval: Int) -> Int {
        guard target > start else { return 0 }
        let elapsed = calendar.dateComponents([cycle.component], from: start, to: target)
            .value(for: cycle.component) ?? 0
        // 월말 보정(1/31 + 1개월 = 2/28) 때문에 생기는 오차를 감안해 한 주기 여유를 둔다
        return max(0, elapsed / max(1, interval) - 1)
    }
}
