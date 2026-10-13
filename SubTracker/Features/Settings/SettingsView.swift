import SwiftUI
import UIKit
import UserNotifications
import WidgetKit

struct SettingsView: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage(AppSettings.Key.defaultCurrency, store: AppSettings.store)
    private var defaultCurrency: Currency = .krw
    @AppStorage(AppSettings.Key.usdToKrw, store: AppSettings.store)
    private var usdRate = AppSettings.defaultUSDRate
    @AppStorage(AppSettings.Key.defaultNotifyDays, store: AppSettings.store)
    private var defaultNotifyDays = AppSettings.defaultNotifyDaysValue

    @State private var authorization: UNAuthorizationStatus = .notDetermined

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
                        Text("원")
                    }
                } header: {
                    Text("통화")
                } footer: {
                    Text("달러 구독은 이 환율로 원화 환산해요. 실시간 환율이 아니니 가끔 직접 업데이트해주세요.")
                }

                Section {
                    Picker("기본 알림", selection: $defaultNotifyDays) {
                        Text("끔").tag(AppSettings.notifyOff)
                        Text("당일").tag(0)
                        Text("1일 전").tag(1)
                        Text("3일 전").tag(3)
                        Text("7일 전").tag(7)
                    }
                    notificationStatusRow
                } header: {
                    Text("알림")
                } footer: {
                    Text("새 구독을 추가할 때 적용되는 기본값이에요. 알림은 오전 9시에 와요.")
                }

                Section("앱 정보") {
                    LabeledContent("버전", value: AppConfig.appVersion)
                    if let url = AppConfig.privacyPolicyURL {
                        Link("개인정보처리방침", destination: url)
                    }
                    if let email = AppConfig.supportEmail, let url = URL(string: "mailto:\(email)") {
                        Link("문의하기", destination: url)
                    }
                }
            }
            .navigationTitle("설정")
            .task { await refreshAuthorization() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await refreshAuthorization() } }
            }
            .onChange(of: usdRate) { _, newValue in
                if newValue <= 0 { usdRate = AppSettings.defaultUSDRate }
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
    }

    @ViewBuilder
    private var notificationStatusRow: some View {
        switch authorization {
        case .authorized, .provisional, .ephemeral:
            LabeledContent("알림 권한", value: "허용됨")
        case .denied:
            VStack(alignment: .leading, spacing: 6) {
                LabeledContent("알림 권한", value: "거부됨")
                Button("설정 앱에서 알림 켜기") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
            }
        case .notDetermined:
            Button("알림 권한 요청") {
                Task {
                    await NotificationService.shared.requestAuthorization()
                    await refreshAuthorization()
                }
            }
        @unknown default:
            LabeledContent("알림 권한", value: "알 수 없음")
        }
    }

    private func refreshAuthorization() async {
        authorization = await NotificationService.shared.authorizationStatus()
    }
}
