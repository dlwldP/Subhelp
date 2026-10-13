import SwiftData
import SwiftUI
import WidgetKit

@main
struct SubscriptionWidgetBundle: WidgetBundle {
    var body: some Widget {
        SubscriptionWidget()
    }
}

struct SubscriptionWidget: Widget {
    let kind = "SubscriptionWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            SubscriptionWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("구독 지출")
        .description("이번 달 결제 예정 금액과 다가오는 결제를 보여줘요.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

// MARK: - Timeline

struct UpcomingPayment: Identifiable {
    let id: UUID
    let name: String
    let colorHex: String
    let price: Decimal
    let currency: Currency
    let days: Int
}

struct SubscriptionEntry: TimelineEntry {
    let date: Date
    let monthTotal: Decimal
    let remainingCount: Int
    let upcoming: [UpcomingPayment]

    static let sample = SubscriptionEntry(
        date: .now,
        monthTotal: 48_900,
        remainingCount: 2,
        upcoming: [
            .init(id: UUID(), name: "넷플릭스", colorHex: "#D64545", price: 13_500, currency: .krw, days: 2),
            .init(id: UUID(), name: "스포티파이", colorHex: "#2E9E5B", price: 10_900, currency: .krw, days: 5),
            .init(id: UUID(), name: "iCloud+", colorHex: "#5B8DEF", price: 4_400, currency: .krw, days: 9),
        ]
    )
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SubscriptionEntry { .sample }

    func getSnapshot(in context: Context, completion: @escaping (SubscriptionEntry) -> Void) {
        completion(context.isPreview ? .sample : makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SubscriptionEntry>) -> Void) {
        // D-day가 바뀌는 자정에 갱신. 데이터 변경은 앱이 reloadAllTimelines()로 알려준다.
        let calendar = Calendar.current
        let midnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: .now)) ?? .now.addingTimeInterval(86_400)
        completion(Timeline(entries: [makeEntry()], policy: .after(midnight)))
    }

    private func makeEntry(now: Date = .now) -> SubscriptionEntry {
        let context = ModelContext(SharedModelContainer.shared)
        let descriptor = FetchDescriptor<Subscription>(predicate: #Predicate { $0.isActive })
        let subscriptions = (try? context.fetch(descriptor)) ?? []

        let billing = BillingCalculator()
        let analyzer = SpendingAnalyzer(billing: billing, cost: CostCalculator(usdToKrw: AppSettings.usdToKrw))
        let summary = analyzer.summary(of: subscriptions.map(\.plan), reference: now)

        let upcoming = subscriptions
            .map { sub in
                let next = billing.nextBillingDate(start: sub.startDate, cycle: sub.cycle,
                                                   interval: sub.cycleInterval, from: now)
                return (next, UpcomingPayment(id: sub.id, name: sub.name, colorHex: sub.colorHex,
                                              price: sub.price, currency: sub.currency,
                                              days: billing.daysUntil(next, from: now)))
            }
            .sorted { $0.0 < $1.0 }
            .prefix(3)
            .map { $0.1 }

        return SubscriptionEntry(date: now, monthTotal: summary.monthTotal,
                                 remainingCount: summary.remainingCount, upcoming: Array(upcoming))
    }
}

// MARK: - Views

struct SubscriptionWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SubscriptionEntry

    var body: some View {
        switch family {
        case .systemMedium:
            HStack(alignment: .top, spacing: 16) {
                totalView
                Divider()
                upcomingList(limit: 3)
            }
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text("이번 달 \(entry.monthTotal.currencyText())")
                    .font(.headline)
                    .widgetAccentable()
                if let next = entry.upcoming.first {
                    Text("\(next.name) \(DDay.text(next.days))")
                        .font(.caption)
                } else {
                    Text("예정된 결제 없음").font(.caption)
                }
            }
        default:
            VStack(alignment: .leading, spacing: 8) {
                totalView
                Spacer(minLength: 0)
                if let next = entry.upcoming.first {
                    HStack(spacing: 6) {
                        InitialIcon(name: next.name, colorHex: next.colorHex, size: 18)
                        Text(next.name).font(.caption).lineLimit(1)
                        Spacer(minLength: 0)
                        Text(DDay.text(next.days)).font(.caption.weight(.semibold))
                    }
                }
            }
        }
    }

    private var totalView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("이번 달")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(entry.monthTotal.currencyText())
                .font(.system(.title3, design: .rounded, weight: .bold))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text("남은 결제 \(entry.remainingCount)건")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: family == .systemMedium ? CGFloat(120) : CGFloat.infinity, alignment: .leading)
    }

    private func upcomingList(limit: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if entry.upcoming.isEmpty {
                Text("구독을 추가해보세요")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ForEach(entry.upcoming.prefix(limit)) { item in
                HStack(spacing: 8) {
                    InitialIcon(name: item.name, colorHex: item.colorHex, size: 22)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(item.name).font(.caption.weight(.medium)).lineLimit(1)
                        Text(item.price.currencyText(item.currency))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    Text(DDay.text(item.days))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(item.days <= 1 ? Color.red : Color.primary)
                }
            }
            Spacer(minLength: 0)
        }
    }
}
