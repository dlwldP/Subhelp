import Charts
import SwiftData
import SwiftUI

/// 통계 탭 (MVP 2) — 카테고리 차트, 결제 캘린더, 비싼 구독 순위
struct StatsView: View {
    @Query(filter: #Predicate<Subscription> { $0.isActive }, sort: \Subscription.createdAt)
    private var subscriptions: [Subscription]
    @AppStorage(AppSettings.Key.usdToKrwRate, store: AppSettings.store) private var usdRate = AppSettings.defaultUSDRate

    private let router = AppRouter.shared
    private let rankingLimit = 5

    private var calculator: InsightCalculator {
        InsightCalculator(billing: BillingCalculator(), cost: CostCalculator(usdToKrw: AppSettings.decimal(usdRate)))
    }

    private var plans: [BillingPlan] { subscriptions.map(\.plan) }

    private var categoryTotals: [CategoryTotal] {
        calculator.categoryTotals(of: subscriptions.map { ($0.category, $0.plan) })
    }

    private var hasEstimate: Bool { subscriptions.contains { $0.currency != .krw } }

    var body: some View {
        @Bindable var router = self.router

        NavigationStack(path: $router.statsPath) {
            Group {
                if subscriptions.isEmpty {
                    ContentUnavailableView {
                        Label("아직 볼 통계가 없어요", systemImage: "chart.pie")
                    } description: {
                        Text("구독을 추가하면 카테고리별 지출과 결제 캘린더를 보여드려요.")
                    } actions: {
                        Button("구독 추가") { router.isAddingSubscription = true }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            categoryCard
                            Card {
                                PaymentCalendarView(subscriptions: subscriptions, calculator: calculator)
                            }
                            rankingCard
                        }
                        .padding()
                    }
                    .background(Color(.systemGroupedBackground))
                }
            }
            .navigationTitle("통계")
            .navigationDestination(for: UUID.self) { SubscriptionDetailView(subscriptionID: $0) }
        }
    }

    // MARK: - 카테고리 (I-01)

    private var categoryCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Text("카테고리별 지출 (월 환산)")
                    .font(.headline)
                if categoryTotals.isEmpty {
                    Text("체험 중인 구독만 있어요. 체험이 끝나면 지출에 포함돼요.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Chart(categoryTotals) { item in
                        SectorMark(angle: .value("금액", item.monthlyCost.doubleValue),
                                   innerRadius: .ratio(0.6), angularInset: 1.5)
                            .cornerRadius(4)
                            .foregroundStyle(by: .value("카테고리", item.category))
                    }
                    .chartForegroundStyleScale(domain: categoryTotals.map(\.category),
                                               range: categoryTotals.indices.map(chartColor))
                    .frame(height: 200)
                    .chartLegend(.hidden)
                    .accessibilityHidden(true)

                    VStack(spacing: 8) {
                        ForEach(Array(categoryTotals.enumerated()), id: \.element.id) { index, item in
                            HStack {
                                Circle()
                                    .fill(chartColor(index))
                                    .frame(width: 10, height: 10)
                                    .accessibilityHidden(true)
                                Text(item.category)
                                Spacer()
                                Text(item.monthlyCost.currencyText(.krw, estimated: hasEstimate))
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                            .font(.subheadline)
                            .accessibilityElement(children: .combine)
                        }
                    }

                    if let top = categoryTotals.first {
                        Text("이번 달 가장 큰 지출은 \(top.category)이에요")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    /// 차트와 범례가 같은 색을 쓰도록 순서대로 지정한다
    private func chartColor(_ index: Int) -> Color {
        let palette: [Color] = [.blue, .green, .orange, .purple, .red, .teal, .yellow, .pink, .indigo, .brown, .mint, .cyan]
        return palette[index % palette.count]
    }

    // MARK: - 비싼 구독 순위 (I-03)

    private var rankingCard: some View {
        let ranked = calculator.ranking(of: plans, limit: rankingLimit)
        return Card {
            VStack(alignment: .leading, spacing: 12) {
                Text("비싼 구독 순위 (월 환산)")
                    .font(.headline)
                if ranked.isEmpty {
                    Text("체험 중인 구독은 순위에서 빠져요.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                ForEach(Array(ranked.enumerated()), id: \.element.planIndex) { rank, item in
                    let sub = subscriptions[item.planIndex]
                    NavigationLink(value: sub.id) {
                        HStack(spacing: 12) {
                            Text("\(rank + 1)")
                                .font(.headline.monospacedDigit())
                                .foregroundStyle(rank == 0 ? Color.accentColor : Color.secondary)
                                .frame(width: 20)
                            InitialIcon(name: sub.name, colorHex: sub.colorHex, size: 32)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(sub.name).font(.subheadline.weight(.medium)).lineLimit(1)
                                Text(sub.priceWithCycleText)
                                    .font(.caption)
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(item.monthlyCost.currencyText(.krw, estimated: sub.currency != .krw))
                                .font(.subheadline.weight(.semibold))
                                .monospacedDigit()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(rank + 1)위, \(sub.name), 한 달에 \(SubscriptionAccessibility.spokenPrice(item.monthlyCost, .krw))")
                }
            }
        }
    }
}
