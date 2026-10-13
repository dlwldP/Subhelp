import SwiftUI
import UIKit
import UserNotifications
import WidgetKit

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.openURL) private var openURL

    @AppStorage(AppSettings.Key.defaultCurrency, store: AppSettings.store)
    private var defaultCurrency: Currency = .krw
    @AppStorage(AppSettings.Key.usdToKrwRate, store: AppSettings.store)
    private var usdRate = AppSettings.defaultUSDRate
    @AppStorage(AppSettings.Key.defaultNotifyDays, store: AppSettings.store)
    private var defaultNotifyDays = AppSettings.defaultNotifyDaysValue
    @AppStorage(AppSettings.Key.notifyHour, store: AppSettings.store)
    private var notifyHour = AppSettings.defaultNotifyHour

    private let router = AppRouter.shared

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("기본 통화", selection: $defaultCurrency) {
                        ForEach(Currency.allCases) { Text($0.displayName).tag($0) }
                    }
                    HStack {
                        Text("1 USD =")
                        TextField("환율", value: $usdRate, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .monospacedDigit()
                        Text("원")
                    }
                } header: {
                    Text("통화·환율")
                } footer: {
                    Text("달러 구독은 이 환율로 원화 환산하고 금액 앞에 ≈를 붙여요. 실시간 환율이 아니니 가끔 직접 바꿔주세요.")
                }

                Section {
                    Picker("기본 알림 시점", selection: $defaultNotifyDays) {
                        Text("끔").tag(AppSettings.notifyOff)
                        Text("당일").tag(0)
                        Text("1일 전").tag(1)
                        Text("3일 전").tag(3)
                        Text("7일 전").tag(7)
                    }
                    Picker("알림 시각", selection: $notifyHour) {
                        ForEach(0..<24, id: \.self) { hour in
                            Text(hourText(hour)).tag(hour)
                        }
                    }
                    notificationStatusRow
                } header: {
                    Text("알림")
                } footer: {
                    Text("알림 시점은 새 구독을 추가할 때의 기본값이에요. 알림 시각은 모든 구독에 적용돼요.")
                }

                Section {
                    LabeledContent("버전", value: AppConfig.appVersion)
                    if let email = AppConfig.supportEmail, let url = URL(string: "mailto:\(email)") {
                        Link("문의하기", destination: url)
                    }
                    if let url = AppConfig.privacyPolicyURL {
                        Link("개인정보처리방침", destination: url)
                    }
                } header: {
                    Text("정보")
                } footer: {
                    Text("모든 데이터는 이 기기에만 저장되고 어디에도 전송되지 않아요. 앱을 삭제하면 등록한 구독도 함께 삭제되니 주의해주세요.")
                }
            }
            .navigationTitle("설정")
            .onChange(of: usdRate) { _, newValue in
                if newValue <= 0 { usdRate = AppSettings.defaultUSDRate }
                WidgetCenter.shared.reloadAllTimelines()
            }
            .onChange(of: notifyHour) { _, _ in
                Task { await SubscriptionSync.refresh(using: context) }
            }
        }
    }

    @ViewBuilder
    private var notificationStatusRow: some View {
        switch router.notificationStatus {
        case .authorized, .provisional, .ephemeral:
            LabeledContent("알림 권한", value: "허용됨")
        case .denied:
            VStack(alignment: .leading, spacing: 6) {
                LabeledContent("알림 권한", value: "꺼짐")
                Button("설정 앱에서 알림 켜기") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
            }
        case .notDetermined:
            Button("알림 허용하기") {
                Task {
                    await NotificationService.shared.requestAuthorization()
                    await router.refreshNotificationStatus()
                    await SubscriptionSync.refresh(using: context)
                }
            }
        @unknown default:
            LabeledContent("알림 권한", value: "알 수 없음")
        }
    }

    private func hourText(_ hour: Int) -> String {
        switch hour {
        case 0:      "오전 12시"
        case 1..<12: "오전 \(hour)시"
        case 12:     "오후 12시"
        default:     "오후 \(hour - 12)시"
        }
    }
}
