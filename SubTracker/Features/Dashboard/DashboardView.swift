import Charts
import SwiftData
import SwiftUI

struct DashboardView: View {
    @Query(filter: #Predicate<Subscription> { $0.isActive }) private var subscriptions: [Subscription]
    @AppStorage(AppSettings.Key.usdToKrw, store: AppSettings.store) private var usdRate = AppSettings.defaultUSDRate
    @State private var isAdding = false

    private let billing = BillingCalculator()
    private let upcomingWindowDays = 7

    private var cost: CostCalculator { CostCalculator(usdToKrw: AppSettings.decimal(usdRate)) }

    private var summary: SpendingSummary {
        SpendingAnalyzer(billing: billing, cost: cost).summary(of: subscriptions.map(\.plan))
    }

    private var upcoming: [UpcomingItem] {
        subscriptions
            .map { sub in
                let date = billing.nextBillingDate(start: sub.startDate, cycle: sub.cycle, interval: sub.cycleInterval)
                return UpcomingItem(subscription: sub, date: date, days: billing.daysUntil(date))
            }
            .filter { $0.days <= upcomingWindowDays }
            .sorted { $0.date < $1.date }
    }

    private var categoryTotals: [CategoryTotal] {
        Dictionary(grouping: subscriptions, by: \.category)
            .map { category, subs in
                CategoryTotal(category: category,
                              amount: subs.reduce(Decimal(0)) { $0 + cost.monthlyCost($1.plan) }.doubleValue)
            }
            .sorted { $0.amount > $1.amount }
    }

    var body: some View {
        NavigationStack {
            Group {
                if subscriptions.isEmpty {
                    ContentUnavailableView {
                        Label("첫 구독을 추가해보세요", systemImage: "creditcard")
                    } description: {
                        Text("결제일 알림과 이번 달 지출을 한눈에 볼 수 있어요.")
                    } actions: {
                        Button("구독 추가") { isAdding = true }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            summaryCard
                            upcomingCard
                            if categoryTotals.count > 0 { categoryCard }
                        }
                        .padding()
                    }
                    .background(Color(.systemGroupedBackground))
                }
            }
            .navigationTitle("홈")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { isAdding = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("구독 추가")
                }
            }
            .sheet(isPresented: $isAdding) { AddSubscriptionSheet() }
        }
    }

    // MARK: - Cards

    private var summaryCard: some View {
        DashboardCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("이번 달 결제 예정")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(summary.monthTotal.currencyText())
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .contentTransition(.numericText())
                Text("남은 결제 \(summary.remainingCount)건 · \(summary.remainingTotal.currencyText())")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Divider()

                HStack {
                    StatView(title: "월 환산 평균", value: summary.monthlyAverage.currencyText())
                    Spacer()
                    StatView(title: "연 환산", value: summary.yearlyTotal.currencyText())
                }
                Text("‘이번 달 결제 예정’은 이번 달에 실제로 빠져나가는 금액이고, ‘월 환산 평균’은 연·주 결제를 월 단위로 나눈 값이에요.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var upcomingCard: some View {
        DashboardCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("다가오는 결제 (\(upcomingWindowDays)일 이내)")
                    .font(.headline)
                if upcoming.isEmpty {
                    Text("일주일 안에 예정된 결제가 없어요.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(upcoming) { item in
                        HStack(spacing: 12) {
                            InitialIcon(name: item.subscription.name, colorHex: item.subscription.colorHex, size: 32)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.subscription.name).font(.subheadline.weight(.medium))
                                Text(item.date.formatted(.dateTime.month().day().weekday()))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(item.subscription.price.currencyText(item.subscription.currency))
                                    .font(.subheadline)
                                Text(DDay.text(item.days))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(item.days <= 1 ? Color.red : Color.accentColor)
                            }
                        }
                    }
                }
            }
        }
    }

    private var categoryCard: some View {
        DashboardCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("카테고리별 (월 환산)")
                    .font(.headline)
                Chart(categoryTotals) { item in
                    SectorMark(angle: .value("금액", item.amount), innerRadius: .ratio(0.6), angularInset: 1.5)
                        .cornerRadius(4)
                        .foregroundStyle(by: .value("카테고리", item.category))
                }
                .frame(height: 200)
                .chartLegend(position: .bottom, spacing: 12)
            }
        }
    }
}

private struct UpcomingItem: Identifiable {
    let subscription: Subscription
    let date: Date
    let days: Int
    var id: UUID { subscription.id }
}

private struct CategoryTotal: Identifiable {
    let category: String
    let amount: Double
    var id: String { category }
}

private struct StatView: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.headline)
        }
    }
}

struct DashboardCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}
