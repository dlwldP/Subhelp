import SwiftUI

/// 월별 결제 캘린더 (I-02) — 날짜별 결제 점 표시, 날짜를 누르면 그날 결제 목록
struct PaymentCalendarView: View {
    let subscriptions: [Subscription]
    let calculator: InsightCalculator

    @State private var month = Calendar.current.startOfDay(for: .now)
    @State private var selectedDay: Date? = Calendar.current.startOfDay(for: .now)

    private var calendar: Calendar { calculator.billing.calendar }
    private var plans: [BillingPlan] { subscriptions.map(\.plan) }
    private var payments: [ScheduledPayment] { calculator.payments(in: month, of: plans) }
    private var paymentsByDay: [Date: [ScheduledPayment]] { Dictionary(grouping: payments, by: \.date) }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    private let maxDots = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            weekdayHeader
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(Array(gridDays.enumerated()), id: \.offset) { _, day in
                    if let day {
                        dayCell(day)
                    } else {
                        Color.clear.frame(height: 44)
                    }
                }
            }
            Divider()
            selectedDayList
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("결제 캘린더")
                    .font(.headline)
                Text("\(month.formatted(.dateTime.year().month(.wide))) · \(payments.count)건 \(calculator.total(of: payments, plans: plans).currencyText(.krw, estimated: hasEstimate))")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button { shiftMonth(-1) } label: { Image(systemName: "chevron.left") }
                .accessibilityLabel("이전 달")
            Button { shiftMonth(1) } label: { Image(systemName: "chevron.right") }
                .accessibilityLabel("다음 달")
                .padding(.leading, 12)
        }
        .buttonStyle(.borderless)
    }

    private var weekdayHeader: some View {
        let symbols = calendar.veryShortWeekdaySymbols
        let first = calendar.firstWeekday - 1
        let ordered = Array(symbols[first...] + symbols[..<first])
        return HStack(spacing: 4) {
            ForEach(Array(ordered.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: - Grid

    /// 앞쪽 빈칸(nil) + 그 달의 날짜들
    private var gridDays: [Date?] {
        guard let interval = calendar.dateInterval(of: .month, for: month),
              let dayCount = calendar.range(of: .day, in: .month, for: month)?.count
        else { return [] }
        let firstWeekday = calendar.component(.weekday, from: interval.start)
        let leading = (firstWeekday - calendar.firstWeekday + 7) % 7
        let days = (0..<dayCount).compactMap { calendar.date(byAdding: .day, value: $0, to: interval.start) }
        return Array(repeating: nil, count: leading) + days.map { Optional($0) }
    }

    private func dayCell(_ day: Date) -> some View {
        let dayPayments = paymentsByDay[day] ?? []
        let isSelected = selectedDay == day
        let isToday = calendar.isDateInToday(day)

        return Button {
            selectedDay = day
        } label: {
            VStack(spacing: 3) {
                Text("\(calendar.component(.day, from: day))")
                    .font(.subheadline.weight(isToday ? .bold : .regular))
                    .monospacedDigit()
                    .foregroundStyle(isSelected ? Color.white : (isToday ? Color.accentColor : Color.primary))
                HStack(spacing: 2) {
                    ForEach(dayPayments.prefix(maxDots), id: \.self) { payment in
                        Circle()
                            .fill(isSelected ? Color.white : Color(hex: subscriptions[payment.planIndex].colorHex))
                            .frame(width: 5, height: 5)
                    }
                }
                .frame(height: 5)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(isSelected ? Color.accentColor : Color.clear, in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(dayAccessibilityLabel(day, count: dayPayments.count))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func dayAccessibilityLabel(_ day: Date, count: Int) -> String {
        let text = day.formatted(.dateTime.month().day())
        return count == 0 ? text : "\(text), 결제 \(count)건"
    }

    // MARK: - Selected day

    @ViewBuilder
    private var selectedDayList: some View {
        if let selectedDay, calendar.isDate(selectedDay, equalTo: month, toGranularity: .month) {
            let dayPayments = paymentsByDay[selectedDay] ?? []
            VStack(alignment: .leading, spacing: 10) {
                Text(selectedDay.formatted(.dateTime.month().day().weekday()))
                    .font(.subheadline.weight(.semibold))
                if dayPayments.isEmpty {
                    Text("이 날은 결제 예정이 없어요")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(dayPayments, id: \.self) { payment in
                        let sub = subscriptions[payment.planIndex]
                        NavigationLink(value: sub.id) {
                            HStack(spacing: 12) {
                                InitialIcon(name: sub.name, colorHex: sub.colorHex, size: 28)
                                Text(sub.name).font(.subheadline).lineLimit(1)
                                Spacer()
                                Text(sub.price.currencyText(sub.currency))
                                    .font(.subheadline)
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(sub.name), \(SubscriptionAccessibility.spokenPrice(sub.price, sub.currency))")
                    }
                }
            }
        } else {
            Text("날짜를 누르면 그날 결제를 보여드려요")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Helpers

    private var hasEstimate: Bool {
        payments.contains { subscriptions[$0.planIndex].currency != .krw }
    }

    private func shiftMonth(_ value: Int) {
        guard let next = calendar.date(byAdding: .month, value: value, to: month) else { return }
        month = next
        // 이번 달로 돌아오면 오늘을, 다른 달이면 1일을 선택
        selectedDay = calendar.isDate(next, equalTo: .now, toGranularity: .month)
            ? calendar.startOfDay(for: .now)
            : calendar.dateInterval(of: .month, for: next)?.start
    }
}
