import SwiftData
import SwiftUI
import WidgetKit

@main
struct SubhelpWidgetBundle: WidgetBundle {
    var body: some Widget {
        SubhelpWidget()
    }
}

struct SubhelpWidget: Widget {
    let kind = "SubhelpWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            SubhelpWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("구독 결제 예정")
        .description("이번 달 결제 예정액과 다가오는 결제를 보여줘요.")
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

struct SubhelpEntry: TimelineEntry {
    let date: Date
    let monthTotal: Decimal
    let isEstimated: Bool
    let remainingCount: Int
    let hasSubscriptions: Bool
    let upcoming: [UpcomingPayment]

    static let sample = SubhelpEntry(
        date: .now,
        monthTotal: 87_400,
        isEstimated: false,
        remainingCount: 3,
        hasSubscriptions: true,
        upcoming: [
            .init(id: UUID(), name: "넷플릭스", colorHex: "#D64545", price: 17_000, currency: .krw, days: 2),
            .init(id: UUID(), name: "스포티파이", colorHex: "#2E9E5B", price: 10_900, currency: .krw, days: 5),
            .init(id: UUID(), name: "iCloud+", colorHex: "#5B8DEF", price: 4_400, currency: .krw, days: 9),
        ]
    )
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SubhelpEntry { .sample }

    func getSnapshot(in context: Context, completion: @escaping (SubhelpEntry) -> Void) {
        completion(context.isPreview ? .sample : makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SubhelpEntry>) -> Void) {
        // D-day가 바뀌는 자정에 갱신. 데이터 변경은 앱이 reloadAllTimelines()로 알려준다.
        let calendar = Calendar.current
        let midnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: .now)) ?? .now.addingTimeInterval(86_400)
        completion(Timeline(entries: [makeEntry()], policy: .after(midnight)))
    }

    private func makeEntry(now: Date = .now) -> SubhelpEntry {
        let context = ModelContext(SharedModelContainer.shared)
        let descriptor = FetchDescriptor<Subscription>(predicate: #Predicate { $0.isActive })
        let subscriptions = (try? context.fetch(descriptor)) ?? []

        let billing = BillingCalculator()
        let analyzer = SpendingAnalyzer(billing: billing, cost: CostCalculator(usdToKrw: AppSettings.usdToKrw))
        let summary = analyzer.summary(of: subscriptions.map(\.plan), reference: now)

        let upcoming = subscriptions
            .map { sub in
                let next = billing.nextPaymentDate(sub.plan, from: now)
                return (next, UpcomingPayment(id: sub.id, name: sub.name, colorHex: sub.colorHex,
                                              price: sub.price, currency: sub.currency,
                                              days: billing.daysUntil(next, from: now)))
            }
            .sorted { $0.0 < $1.0 }
            .prefix(3)
            .map { $0.1 }

        return SubhelpEntry(date: now, monthTotal: summary.monthTotal, isEstimated: summary.isEstimated,
                            remainingCount: summary.remainingCount, hasSubscriptions: !subscriptions.isEmpty,
                            upcoming: Array(upcoming))
    }
}

// MARK: - Views

struct SubhelpWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SubhelpEntry

    private var monthTitle: String {
        "\(Calendar.current.component(.month, from: entry.date))월 결제 예정"
    }

    var body: some View {
        if !entry.hasSubscriptions {
            emptyView
                .widgetURL(DeepLink.home)
        } else {
            switch family {
            case .systemMedium:
                HStack(alignment: .top, spacing: 16) {
                    totalView
                        .frame(width: 120, alignment: .leading)
                    Divider()
                    upcomingList
                }
                .widgetURL(DeepLink.home)
            case .accessoryRectangular:
                lockScreenView
                    .widgetURL(entry.upcoming.first.map { DeepLink.subscription($0.id) } ?? DeepLink.home)
            default:
                totalView
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .widgetURL(DeepLink.home)
            }
        }
    }

    private var emptyView: some View {
        VStack(alignment: .leading, spacing: 4) {
            if family != .accessoryRectangular {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
            }
            Text("구독을 추가해보세요")
                .font(.caption.weight(.medium))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var totalView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(monthTitle)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(entry.monthTotal.currencyText(.krw, estimated: entry.isEstimated))
                .font(.system(.title3, design: .rounded, weight: .bold))
                .monospacedDigit()
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            Text("남은 \(entry.remainingCount)건")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private var upcomingList: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(entry.upcoming) { item in
                Link(destination: DeepLink.subscription(item.id)) {
                    HStack(spacing: 8) {
                        InitialIcon(name: item.name, colorHex: item.colorHex, size: 22)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(item.name).font(.caption.weight(.medium)).lineLimit(1)
                            Text(item.price.currencyText(item.currency))
                                .font(.caption2)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                        Text(DDay.text(item.days))
                            .font(.caption.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(DDay.urgency(item.days) == .imminent ? Color.orange : Color.primary)
                    }
                }
                .accessibilityLabel("\(item.name), \(SubscriptionAccessibility.spokenPrice(item.price, item.currency)), \(DDay.spoken(item.days))")
            }
            Spacer(minLength: 0)
        }
    }

    private var lockScreenView: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("다음 결제")
                .font(.caption2)
                .foregroundStyle(.secondary)
            if let next = entry.upcoming.first {
                Text(next.name)
                    .font(.headline)
                    .lineLimit(1)
                    .widgetAccentable()
                Text("\(DDay.text(next.days)) · \(next.price.currencyText(next.currency))")
                    .font(.caption)
                    .monospacedDigit()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
