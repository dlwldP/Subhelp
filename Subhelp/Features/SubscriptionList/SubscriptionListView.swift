import SwiftData
import SwiftUI

struct SubscriptionListView: View {
    enum Filter: String, CaseIterable, Identifiable {
        case active = "활성"
        case paused = "일시중지"
        var id: Self { self }
    }

    @Environment(\.modelContext) private var context
    @Query(sort: \Subscription.createdAt) private var subscriptions: [Subscription]
    @State private var filter: Filter = .active
    @State private var pendingDeletion: Subscription?

    private let router = AppRouter.shared
    private let billing = BillingCalculator()

    /// 다음 결제일 가까운 순
    private var rows: [SubscriptionRowModel] {
        subscriptions
            .filter { $0.isActive == (filter == .active) }
            .map { sub in
                let next = billing.nextPaymentDate(sub.plan)
                return SubscriptionRowModel(subscription: sub, nextDate: next, days: billing.daysUntil(next),
                                            isInTrial: billing.isInTrial(sub.plan))
            }
            .sorted { $0.nextDate == $1.nextDate ? $0.subscription.name < $1.subscription.name : $0.nextDate < $1.nextDate }
    }

    var body: some View {
        @Bindable var router = self.router

        NavigationStack(path: $router.subscriptionsPath) {
            List {
                Section {
                    Picker("상태", selection: $filter) {
                        ForEach(Filter.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }

                Section {
                    ForEach(rows) { row in
                        NavigationLink(value: row.subscription.id) {
                            SubscriptionRow(model: row)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) { pendingDeletion = row.subscription } label: {
                                Label("삭제", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading) {
                            Button { toggleActive(row.subscription) } label: {
                                row.subscription.isActive
                                    ? Label("일시중지", systemImage: "pause.circle")
                                    : Label("재개", systemImage: "play.circle")
                            }
                            .tint(row.subscription.isActive ? Color.orange : Color.green)
                        }
                    }
                } footer: {
                    if filter == .paused && !rows.isEmpty {
                        Text("일시중지한 구독은 모든 합계와 알림에서 제외돼요.")
                    }
                }
            }
            .overlay {
                if rows.isEmpty {
                    ContentUnavailableView(
                        filter == .active ? "아직 등록된 구독이 없어요" : "일시중지한 구독이 없어요",
                        systemImage: "tray",
                        description: Text(filter == .active
                                          ? "오른쪽 위 + 버튼으로 첫 구독을 추가해볼까요?"
                                          : "해지한 구독을 일시중지하면 기록은 남기고 합계에서 빼드려요.")
                    )
                }
            }
            .navigationTitle("구독")
            .navigationDestination(for: UUID.self) { SubscriptionDetailView(subscriptionID: $0) }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { router.isAddingSubscription = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("구독 추가")
                }
            }
            .confirmationDialog(
                "‘\(pendingDeletion?.name ?? "")’ 구독을 삭제할까요?",
                isPresented: Binding(get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } }),
                titleVisibility: .visible,
                presenting: pendingDeletion
            ) { sub in
                Button("삭제", role: .destructive) { delete(sub) }
                Button("일시중지", action: { pause(sub) })
            } message: { _ in
                Text("삭제하면 되돌릴 수 없어요. 기록을 남기려면 일시중지를 사용해보세요.")
            }
        }
    }

    private func delete(_ subscription: Subscription) {
        context.delete(subscription)
        Task { await SubscriptionSync.commit(context) }
    }

    private func pause(_ subscription: Subscription) {
        subscription.isActive = false
        Task { await SubscriptionSync.commit(context) }
    }

    private func toggleActive(_ subscription: Subscription) {
        subscription.isActive.toggle()
        Task { await SubscriptionSync.commit(context) }
    }
}

struct SubscriptionRowModel: Identifiable {
    let subscription: Subscription
    let nextDate: Date
    let days: Int
    let isInTrial: Bool
    var id: UUID { subscription.id }
}

struct SubscriptionRow: View {
    let model: SubscriptionRowModel

    private var sub: Subscription { model.subscription }

    var body: some View {
        HStack(spacing: 12) {
            InitialIcon(name: sub.name, colorHex: sub.colorHex)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(sub.name)
                        .font(.body.weight(.medium))
                        .lineLimit(1)
                    if model.isInTrial && sub.isActive {
                        Text("체험 중")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .foregroundStyle(Color.accentColor)
                            .background(Color.accentColor.opacity(0.15), in: Capsule())
                    }
                }
                Text(sub.priceWithCycleText)
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if sub.isActive {
                DDayBadge(days: model.days)
            } else {
                Text("일시중지")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .opacity(sub.isActive ? 1 : 0.5)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        var text = SubscriptionAccessibility.label(sub, days: sub.isActive ? model.days : nil)
        if model.isInTrial && sub.isActive { text += ", 체험 중" }
        if !sub.isActive { text += ", 일시중지" }
        return text
    }
}
