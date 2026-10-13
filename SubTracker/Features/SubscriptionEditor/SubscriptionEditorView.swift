import SwiftData
import SwiftUI

struct SubscriptionEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var draft: SubscriptionDraft
    @State private var isConfirmingDelete = false

    /// nil이면 새 구독 추가
    private let editing: Subscription?
    /// 추가 완료 시 시트를 닫기 위한 콜백 (편집 모드에서는 dismiss로 pop)
    private let onFinish: (() -> Void)?

    private let billing = BillingCalculator()
    private let notifyOptions: [Int] = [0, 1, 3, 7]

    init(draft: SubscriptionDraft, onFinish: @escaping () -> Void) {
        _draft = State(initialValue: draft)
        editing = nil
        self.onFinish = onFinish
    }

    init(subscription: Subscription) {
        _draft = State(initialValue: SubscriptionDraft(subscription: subscription))
        editing = subscription
        onFinish = nil
    }

    private var nextBillingDate: Date {
        billing.nextBillingDate(start: draft.startDate, cycle: draft.cycle, interval: draft.interval)
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
                    Picker("통화", selection: $draft.currency) {
                        ForEach(Currency.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .fixedSize()
                }
            } header: {
                Text("기본 정보")
            } footer: {
                if !draft.isPriceValid && !draft.trimmedName.isEmpty {
                    Text("0보다 큰 금액을 입력해주세요.")
                        .foregroundStyle(.red)
                }
            }

            Section {
                Picker("주기", selection: $draft.cycle) {
                    ForEach(BillingCycle.allCases) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.segmented)
                Stepper(draft.cycle.label(interval: draft.interval), value: $draft.interval, in: 1...12)
                DatePicker("최초 결제일", selection: $draft.startDate, displayedComponents: .date)
            } header: {
                Text("결제 주기")
            } footer: {
                Text("다음 결제일: \(nextBillingDate.formatted(date: .long, time: .omitted)) (\(DDay.text(billing.daysUntil(nextBillingDate))))")
            }

            Section("알림") {
                Picker("결제 알림", selection: $draft.notifyDaysBefore) {
                    Text("끔").tag(Int?.none)
                    ForEach(notifyOptions, id: \.self) { days in
                        Text(days == 0 ? "당일" : "\(days)일 전").tag(Int?.some(days))
                    }
                }
                Toggle("무료체험 중", isOn: $draft.hasTrial.animation())
                if draft.hasTrial {
                    DatePicker("체험 종료일", selection: $draft.trialEndDate, displayedComponents: .date)
                }
            }

            Section("분류") {
                Picker("카테고리", selection: $draft.category) {
                    ForEach(SubscriptionCategory.all, id: \.self) { Text($0).tag($0) }
                }
                ColorSwatchPicker(selection: $draft.colorHex)
            }

            Section("메모") {
                TextField("메모 (선택)", text: $draft.memo, axis: .vertical)
                    .lineLimit(1...4)
            }

            if editing != nil {
                Section {
                    Toggle("활성 (결제 중)", isOn: $draft.isActive)
                } footer: {
                    Text("해지했지만 기록을 남기고 싶다면 끄세요. 알림과 지출 합계에서 빠져요.")
                }
                Section {
                    Button("구독 삭제", role: .destructive) { isConfirmingDelete = true }
                }
            }
        }
        .navigationTitle(editing == nil ? "구독 추가" : "구독 편집")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("저장", action: save)
                    .disabled(!draft.isValid)
            }
        }
        .confirmationDialog("이 구독을 삭제할까요?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button("삭제", role: .destructive, action: delete)
        } message: {
            Text("삭제하면 되돌릴 수 없어요. 기록을 남기려면 일시중지를 사용하세요.")
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
            Task {
                // 알림 권한은 첫 구독을 추가한 직후에 요청한다 (수락률이 높다)
                await NotificationService.shared.requestAuthorizationIfNeeded()
                await SubscriptionSync.commit(context)
            }
            onFinish?()
        }
    }

    private func delete() {
        guard let editing else { return }
        context.delete(editing)
        Task { await SubscriptionSync.commit(context) }
        dismiss()
    }
}

private struct ColorSwatchPicker: View {
    @Binding var selection: String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(ColorPalette.hexes, id: \.self) { hex in
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
                        .onTapGesture { selection = hex }
                        .accessibilityAddTraits(hex == selection ? [.isButton, .isSelected] : .isButton)
                }
            }
            .padding(.vertical, 4)
        }
    }
}
