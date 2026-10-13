import SwiftData
import SwiftUI

/// 구독 상세 — 다음 결제일, 월 환산, 지금까지 낸 총액(추정), 알림 설정 + 편집·일시중지·삭제
struct SubscriptionDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var matches: [Subscription]
    @AppStorage(AppSettings.Key.usdToKrwRate, store: AppSettings.store) private var usdRate = AppSettings.defaultUSDRate

    @State private var isEditing = false
    @State private var isConfirmingDelete = false

    private let billing = BillingCalculator()

    init(subscriptionID: UUID) {
        _matches = Query(filter: #Predicate<Subscription> { $0.id == subscriptionID })
    }

    var body: some View {
        if let sub = matches.first {
            content(sub)
        } else {
            ContentUnavailableView("구독을 찾을 수 없어요", systemImage: "questionmark.circle",
                                   description: Text("삭제된 구독일 수 있어요."))
        }
    }

    private func content(_ sub: Subscription) -> some View {
        let plan = sub.plan
        let rate = AppSettings.decimal(usdRate)
        let cost = CostCalculator(usdToKrw: rate)
        let next = billing.nextPaymentDate(plan)
        let days = billing.daysUntil(next)
        let inTrial = billing.isInTrial(plan)
        let paidCount = billing.paidCount(plan)
        let paidTotal = cost.toKRW(sub.price, currency: sub.currency) * Decimal(paidCount)
        let isUSD = sub.currency != .krw

        return List {
            Section {
                VStack(spacing: 8) {
                    InitialIcon(name: sub.name, colorHex: sub.colorHex, size: 64)
                    Text(sub.name)
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                    Text(sub.priceWithCycleText)
                        .font(.headline)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    if !sub.isActive {
                        Text("일시중지됨 · 합계에서 제외돼요")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if inTrial {
                        Text("체험 중")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .foregroundStyle(Color.accentColor)
                            .background(Color.accentColor.opacity(0.15), in: Capsule())
                    }
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
                .accessibilityElement(children: .combine)
            }

            Section("결제") {
                if sub.isActive {
                    LabeledContent("다음 결제일") {
                        HStack(spacing: 8) {
                            Text(next.formatted(date: .long, time: .omitted))
                            DDayBadge(days: days)
                        }
                    }
                }
                if let trialEnd = sub.trialEndDate {
                    LabeledContent("체험 종료일", value: trialEnd.formatted(date: .long, time: .omitted))
                }
                LabeledContent("결제 주기", value: sub.cycle.label(interval: sub.cycleInterval))
                LabeledContent("첫 결제일", value: sub.startDate.formatted(date: .long, time: .omitted))
                if isUSD {
                    LabeledContent("원화 환산", value: cost.toKRW(sub.price, currency: sub.currency).currencyText(.krw, estimated: true))
                }
                LabeledContent("월 환산", value: cost.monthlyCost(plan).currencyText(.krw, estimated: isUSD))
                    .monospacedDigit()
            }

            Section {
                LabeledContent("지금까지 낸 총액", value: paidTotal.currencyText(.krw, estimated: true))
                    .monospacedDigit()
            } footer: {
                Text("첫 결제일부터 오늘까지 \(paidCount)회 × 현재 금액으로 계산한 추정치예요. 요금이 바뀌었거나 중간에 쉬었다면 실제와 다를 수 있어요.")
            }

            Section("기타") {
                LabeledContent("알림", value: notifyText(sub.notifyDaysBefore))
                LabeledContent("카테고리", value: sub.category)
                if !sub.memo.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("메모").font(.caption).foregroundStyle(.secondary)
                        Text(sub.memo)
                    }
                }
            }

            Section {
                Button(sub.isActive ? "일시중지" : "다시 결제 중으로 바꾸기") { toggleActive(sub) }
                Button("구독 삭제", role: .destructive) { isConfirmingDelete = true }
            }
        }
        .navigationTitle(sub.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("편집") { isEditing = true }
            }
        }
        .sheet(isPresented: $isEditing) {
            NavigationStack {
                SubscriptionEditorView(subscription: sub)
            }
        }
        .confirmationDialog("‘\(sub.name)’ 구독을 삭제할까요?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button("삭제", role: .destructive) { delete(sub) }
        } message: {
            Text("삭제하면 되돌릴 수 없어요. 기록을 남기려면 일시중지를 사용해보세요.")
        }
    }

    private func notifyText(_ days: Int?) -> String {
        guard let days else { return "끔" }
        let hour = AppSettings.notifyHour
        return days == 0 ? "당일 \(hour)시" : "\(days)일 전 \(hour)시"
    }

    private func toggleActive(_ sub: Subscription) {
        SubscriptionSync.setActive(!sub.isActive, for: sub)
        Task { await SubscriptionSync.commit(context) }
    }

    private func delete(_ sub: Subscription) {
        dismiss()
        SubscriptionSync.delete(sub, in: context)
        Task { await SubscriptionSync.commit(context) }
    }
}
