import SwiftData
import SwiftUI

/// 구독 추가·편집 폼.
/// "10초 등록": 필수 항목은 위에, 선택 항목(색상·알림·무료체험·메모)은 "더보기"로 접는다.
struct SubscriptionEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var draft: SubscriptionDraft
    @State private var isShowingOptions: Bool

    /// nil이면 새 구독 추가
    private let editing: Subscription?
    /// 추가 완료 시 시트를 닫기 위한 콜백 (프리셋 화면에서 push된 상태라 dismiss로는 pop만 된다)
    private let onFinish: (() -> Void)?

    private let billing = BillingCalculator()
    private let notifyOptions: [Int] = [0, 1, 3, 7]

    init(draft: SubscriptionDraft, onFinish: @escaping () -> Void) {
        _draft = State(initialValue: draft)
        _isShowingOptions = State(initialValue: draft.hasCustomOptions)
        editing = nil
        self.onFinish = onFinish
    }

    init(subscription: Subscription) {
        let draft = SubscriptionDraft(subscription: subscription)
        _draft = State(initialValue: draft)
        _isShowingOptions = State(initialValue: draft.hasCustomOptions)
        editing = subscription
        onFinish = nil
    }

    private var nextPaymentDate: Date {
        let plan = BillingPlan(price: draft.price, currency: draft.currency, cycle: draft.cycle,
                               interval: draft.interval, startDate: draft.startDate,
                               trialEndDate: draft.hasTrial ? draft.trialEndDate : nil)
        return billing.nextPaymentDate(plan)
    }

    var body: some View {
        Form {
            Section {
                HStack(spacing: 12) {
                    InitialIcon(name: draft.name, colorHex: draft.colorHex)
                    TextField("서비스 이름", text: $draft.name)
                        .textInputAutocapitalization(.never)
                }
                HStack {
                    TextField("금액", value: $draft.price, format: .number)
                        .keyboardType(.decimalPad)
                        .monospacedDigit()
                    Picker("통화", selection: $draft.currency) {
                        ForEach(Currency.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .fixedSize()
                }
            } header: {
                Text("필수 정보")
            } footer: {
                if let message = priceMessage {
                    Text(message).foregroundStyle(.red)
                }
            }

            Section {
                Picker("주기", selection: $draft.cycle) {
                    ForEach(BillingCycle.allCases) { Text($0.label(interval: 1)).tag($0) }
                }
                .pickerStyle(.segmented)
                Stepper(draft.cycle.label(interval: draft.interval), value: $draft.interval, in: 1...12)
                DatePicker("첫 결제일", selection: $draft.startDate, displayedComponents: .date)
                Picker("카테고리", selection: $draft.category) {
                    ForEach(SubscriptionCategory.all, id: \.self) { Text($0).tag($0) }
                }
            } footer: {
                Text("다음 결제일은 \(nextPaymentDate.formatted(date: .long, time: .omitted))이에요 (\(DDay.text(billing.daysUntil(nextPaymentDate))))")
            }

            Section {
                DisclosureGroup("더보기 · 색상, 알림, 무료체험, 메모", isExpanded: $isShowingOptions) {
                    ColorSwatchPicker(selection: $draft.colorHex)

                    Picker("결제 알림", selection: $draft.notifyDaysBefore) {
                        Text("끔").tag(Int?.none)
                        ForEach(notifyOptions, id: \.self) { days in
                            Text(days == 0 ? "당일" : "\(days)일 전").tag(Int?.some(days))
                        }
                    }

                    Toggle("무료체험 중", isOn: $draft.hasTrial.animation())
                    if draft.hasTrial {
                        DatePicker("체험 종료일", selection: $draft.trialEndDate, displayedComponents: .date)
                        Text("체험이 끝나는 날부터 결제 예정액에 포함되고, 종료 3일 전과 1일 전에 알려드려요.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    TextField("메모", text: $draft.memo, axis: .vertical)
                        .lineLimit(1...4)
                }
            }
        }
        .navigationTitle(editing == nil ? "구독 추가" : "구독 편집")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if editing != nil {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("저장하기", action: save)
                    .disabled(!draft.isValid)
            }
        }
        .onChange(of: draft.hasTrial) { _, hasTrial in
            // 새로 추가할 때는 보통 체험 종료일 = 첫 결제일이라 맞춰준다
            if editing == nil && hasTrial { draft.startDate = draft.trialEndDate }
        }
        .onChange(of: draft.trialEndDate) { _, trialEnd in
            if editing == nil && draft.hasTrial { draft.startDate = trialEnd }
        }
    }

    private var priceMessage: String? {
        guard !draft.trimmedName.isEmpty else { return nil }
        switch draft.priceProblem {
        case .notPositive: return "0원은 저장할 수 없어요. 금액을 입력해주세요."
        case .tooLarge:    return "금액은 9자리까지 입력할 수 있어요."
        case nil:          return nil
        }
    }

    private func save() {
        guard draft.isValid else { return }

        if let editing {
            draft.apply(to: editing)
            Task { await SubscriptionSync.commit(context) }
            dismiss()
        } else {
            context.insert(draft.makeSubscription())
            AppRouter.shared.shouldOfferNotificationPermission = true
            Task { await SubscriptionSync.commit(context) }
            onFinish?()
        }
    }
}

private struct ColorSwatchPicker: View {
    @Binding var selection: String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(ColorPalette.hexes, id: \.self) { hex in
                    Button { selection = hex } label: {
                        Circle()
                            .fill(Color(hex: hex))
                            .frame(width: 28, height: 28)
                            .overlay {
                                if hex == selection {
                                    Image(systemName: "checkmark")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.white)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("색상 \(hex)")
                    .accessibilityAddTraits(hex == selection ? .isSelected : [])
                }
            }
            .padding(.vertical, 4)
        }
    }
}
