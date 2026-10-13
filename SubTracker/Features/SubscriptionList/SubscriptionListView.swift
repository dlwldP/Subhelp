import SwiftData
import SwiftUI

struct SubscriptionListView: View {
    enum Filter: String, CaseIterable, Identifiable {
        case active = "활성"
        case inactive = "비활성"
        var id: Self { self }
    }

    @Environment(\.modelContext) private var context
    @Query(sort: \Subscription.createdAt) private var subscriptions: [Subscription]
    @State private var filter: Filter = .active
    @State private var isAdding = false

    private let billing = BillingCalculator()

    /// 다음 결제일 가까운 순
    private var rows: [SubscriptionRowModel] {
        subscriptions
            .filter { $0.isActive == (filter == .active) }
            .map { sub in
                let next = billing.nextBillingDate(start: sub.startDate, cycle: sub.cycle, interval: sub.cycleInterval)
                return SubscriptionRowModel(subscription: sub, nextDate: next, days: billing.daysUntil(next))
            }
            .sorted { $0.nextDate == $1.nextDate ? $0.subscription.name < $1.subscription.name : $0.nextDate < $1.nextDate }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("상태", selection: $filter) {
                        ForEach(Filter.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }

                ForEach(rows) { row in
                    NavigationLink(value: row.subscription) {
                        SubscriptionRow(model: row)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) { delete(row.subscription) } label: {
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
            }
            .overlay {
                if rows.isEmpty {
                    ContentUnavailableView(
                        filter == .active ? "활성 구독이 없어요" : "비활성 구독이 없어요",
                        systemImage: "tray",
                        description: Text(filter == .active ? "오른쪽 위 + 버튼으로 첫 구독을 추가해보세요." : "일시중지한 구독이 여기에 모여요.")
                    )
                }
            }
            .navigationTitle("구독")
            .navigationDestination(for: Subscription.self) { SubscriptionEditorView(subscription: $0) }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { isAdding = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("구독 추가")
                }
            }
            .sheet(isPresented: $isAdding) { AddSubscriptionSheet() }
        }
    }

    private func delete(_ subscription: Subscription) {
        context.delete(subscription)
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
    var id: UUID { subscription.id }
}

struct SubscriptionRow: View {
    let model: SubscriptionRowModel

    private var sub: Subscription { model.subscription }

    var body: some View {
        HStack(spacing: 12) {
            InitialIcon(name: sub.name, colorHex: sub.colorHex)
            VStack(alignment: .leading, spacing: 2) {
                Text(sub.name)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                Text("\(sub.price.currencyText(sub.currency)) / \(sub.cycle.label(interval: sub.cycleInterval))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let trialEnd = sub.trialEndDate, trialEnd >= Calendar.current.startOfDay(for: .now) {
                    Text("무료체험 ~ \(trialEnd.formatted(.dateTime.month().day()))")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
            Spacer()
            if sub.isActive {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(DDay.text(model.days))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(model.days <= 1 ? Color.red : Color.primary)
                    Text(model.nextDate.formatted(.dateTime.month().day()))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("일시중지")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
