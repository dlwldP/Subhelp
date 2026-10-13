import Charts
import SwiftData
import SwiftUI
import UIKit

struct HomeView: View {
    @Query(filter: #Predicate<Subscription> { $0.isActive }) private var subscriptions: [Subscription]
    @AppStorage(AppSettings.Key.usdToKrwRate, store: AppSettings.store) private var usdRate = AppSettings.defaultUSDRate
    @State private var isShowingAllUpcoming = false

    private let router = AppRouter.shared
    private let billing = BillingCalculator()
    private let upcomingWindowDays = 7
    private let upcomingPreviewLimit = 5

    private var cost: CostCalculator { CostCalculator(usdToKrw: AppSettings.decimal(usdRate)) }

    private var summary: SpendingSummary {
        SpendingAnalyzer(billing: billing, cost: cost).summary(of: subscriptions.map(\.plan))
    }

    private var upcoming: [UpcomingItem] {
        subscriptions
            .map { sub in
                let date = billing.nextPaymentDate(sub.plan)
                return UpcomingItem(subscription: sub, date: date, days: billing.daysUntil(date))
            }
            .filter { $0.days <= upcomingWindowDays }
            .sorted { $0.date < $1.date }
    }

    private var trials: [UpcomingItem] {
        subscriptions
            .filter { billing.isInTrial($0.plan) }
            .compactMap { sub in
                guard let end = sub.trialEndDate else { return nil }
                return UpcomingItem(subscription: sub, date: end, days: billing.daysUntil(end))
            }
            .sorted { $0.date < $1.date }
    }

    private var categoryTotals: [CategoryTotal] {
        Dictionary(grouping: subscriptions.filter { !billing.isInTrial($0.plan) }, by: \.category)
            .map { category, subs in
                CategoryTotal(category: category,
                              amount: subs.reduce(Decimal(0)) { $0 + cost.monthlyCost($1.plan) }.doubleValue)
            }
            .sorted { $0.amount > $1.amount }
    }

    private var monthTitle: String {
        "\(Calendar.current.component(.month, from: .now))월 결제 예정"
    }

    var body: some View {
        @Bindable var router = self.router

        NavigationStack(path: $router.homePath) {
            Group {
                if subscriptions.isEmpty {
                    ContentUnavailableView {
                        Label("아직 등록된 구독이 없어요", systemImage: "creditcard")
                    } description: {
                        Text("첫 구독을 추가해볼까요?")
                    } actions: {
                        Button("구독 추가") { router.isAddingSubscription = true }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            if router.isNotificationDenied { NotificationDeniedBanner() }
                            summaryCard
                            upcomingCard
                            if !trials.isEmpty { trialCard }
                            if !categoryTotals.isEmpty { categoryCard }
                        }
                        .padding()
                    }
                    .background(Color(.systemGroupedBackground))
                }
            }
            .navigationTitle("홈")
            .navigationDestination(for: UUID.self) { SubscriptionDetailView(subscriptionID: $0) }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { router.isAddingSubscription = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("구독 추가")
                }
            }
        }
    }

    // MARK: - Cards

    private var summaryCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Text(monthTitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(summary.monthTotal.currencyText(.krw, estimated: summary.isEstimated))
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .monospacedDigit()
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                Text("남은 결제 \(summary.remainingCount)건")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Divider()

                ViewThatFits(in: .horizontal) {
                    HStack {
                        StatView(title: "월 환산", value: summary.monthlyAverage.currencyText(.krw, estimated: summary.isEstimated))
                        Spacer()
                        StatView(title: "연 환산", value: summary.yearlyTotal.currencyText(.krw, estimated: summary.isEstimated))
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        StatView(title: "월 환산", value: summary.monthlyAverage.currencyText(.krw, estimated: summary.isEstimated))
                        StatView(title: "연 환산", value: summary.yearlyTotal.currencyText(.krw, estimated: summary.isEstimated))
                    }
                }
                Text("결제 예정액은 이번 달에 실제로 빠져나가는 금액이고, 월 환산은 연·주 결제를 한 달 평균으로 나눈 금액이에요. 체험 중인 구독은 체험이 끝난 뒤부터 포함돼요.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var upcomingCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Text("다가오는 결제")
                    .font(.headline)
                if upcoming.isEmpty {
                    Text("일주일 동안 결제 예정이 없어요")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    let visible = isShowingAllUpcoming ? upcoming : Array(upcoming.prefix(upcomingPreviewLimit))
                    ForEach(visible) { item in
                        NavigationLink(value: item.subscription.id) {
                            UpcomingRow(item: item)
                        }
                        .buttonStyle(.plain)
                    }
                    if upcoming.count > upcomingPreviewLimit {
                        Button(isShowingAllUpcoming ? "접기" : "더보기 (\(upcoming.count - upcomingPreviewLimit)건)") {
                            withAnimation { isShowingAllUpcoming.toggle() }
                        }
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    private var trialCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Text("체험 중")
                    .font(.headline)
                ForEach(trials) { item in
                    NavigationLink(value: item.subscription.id) {
                        HStack(spacing: 12) {
                            InitialIcon(name: item.subscription.name, colorHex: item.subscription.colorHex, size: 32)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.subscription.name).font(.subheadline.weight(.medium))
                                Text("\(item.date.formatted(.dateTime.month().day())) 체험 종료")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(item.days == 1 ? "내일 종료" : "\(item.days)일 후 종료")
                                .font(.subheadline.weight(.semibold))
                                .monospacedDigit()
                                .foregroundStyle(item.days <= 3 ? Color.orange : Color.accentColor)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(item.subscription.name), 무료체험 \(item.days)일 후 종료")
                }
            }
        }
    }

    private var categoryCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Text("카테고리별 지출 (월 환산)")
                    .font(.headline)
                Chart(categoryTotals) { item in
                    SectorMark(angle: .value("금액", item.amount), innerRadius: .ratio(0.6), angularInset: 1.5)
                        .cornerRadius(4)
                        .foregroundStyle(by: .value("카테고리", item.category))
                }
                .frame(height: 200)
                .chartLegend(position: .bottom, spacing: 12)
                if let top = categoryTotals.first {
                    Text("가장 큰 지출은 \(top.category)이에요")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
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

private struct UpcomingRow: View {
    let item: UpcomingItem

    var body: some View {
        HStack(spacing: 12) {
            InitialIcon(name: item.subscription.name, colorHex: item.subscription.colorHex, size: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.subscription.name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Text(item.subscription.price.currencyText(item.subscription.currency))
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Spacer()
            DDayBadge(days: item.days)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(SubscriptionAccessibility.label(item.subscription, days: item.days))
    }
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
            Text(value).font(.headline).monospacedDigit()
        }
    }
}

/// 알림 권한이 거부됐을 때 홈 상단 안내
struct NotificationDeniedBanner: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "bell.slash")
                .foregroundStyle(.orange)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text("알림이 꺼져 있어요")
                    .font(.subheadline.weight(.semibold))
                Text("결제 전에 알려드리려면 설정에서 알림을 켜주세요.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button("설정 열기") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
                .font(.footnote.weight(.semibold))
            }
            Spacer(minLength: 0)
        }
        .padding()
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
    }
}
