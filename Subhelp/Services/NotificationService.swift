import Foundation
import UserNotifications

/// 결제일·무료체험 로컬 알림.
///
/// - 구독마다 다음 결제 2회분만 예약한다 (iOS 대기 알림 한도 64개)
/// - 재예약 시점: 앱 실행·포그라운드 복귀, 구독 변경 (시간대가 바뀌어도 다음 실행 때 바로잡힌다)
/// - 전부 지우고 다시 거는 방식 → 단순하고 버그가 적다
/// - 한도를 넘으면 가까운 알림부터 남긴다 (구독 50개 이상 대응)
@MainActor
final class NotificationService {
    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()
    private let calendar = Calendar.current
    private let billing = BillingCalculator()

    private let pendingLimit = 64
    private let occurrencesPerSubscription = 2
    private let trialReminderDays = [3, 1]

    private init() {}

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    @discardableResult
    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    func rescheduleAll(_ subscriptions: [Subscription], now: Date = .now) async {
        center.removeAllPendingNotificationRequests()

        let status = await authorizationStatus()
        guard status == .authorized || status == .provisional else { return }

        let hour = AppSettings.notifyHour
        var pending: [(fireDate: Date, request: UNNotificationRequest)] = []
        for sub in subscriptions where sub.isActive {
            pending += billingRequests(for: sub, hour: hour, now: now)
            pending += trialRequests(for: sub, hour: hour, now: now)
        }

        for item in pending.sorted(by: { $0.fireDate < $1.fireDate }).prefix(pendingLimit) {
            try? await center.add(item.request)
        }
    }

    // MARK: - Private

    private func billingRequests(for sub: Subscription, hour: Int, now: Date) -> [(fireDate: Date, request: UNNotificationRequest)] {
        guard let days = sub.notifyDaysBefore else { return [] }

        let plan = sub.plan
        var result: [(fireDate: Date, request: UNNotificationRequest)] = []
        var reference = now
        for index in 0..<occurrencesPerSubscription {
            let paymentDate = billing.nextPaymentDate(plan, from: reference)
            if let schedule = fireSchedule(daysBefore: days, of: paymentDate, hour: hour), schedule.fireDate > now {
                let content = UNMutableNotificationContent()
                content.title = "결제 알림"
                content.body = "\(sub.name) 결제가 \(Self.relativeDay(days)) · \(sub.price.currencyText(sub.currency))"
                content.sound = .default
                content.userInfo = ["subscriptionID": sub.id.uuidString]
                let trigger = UNCalendarNotificationTrigger(dateMatching: schedule.components, repeats: false)
                result.append((schedule.fireDate, UNNotificationRequest(identifier: "\(sub.id.uuidString)-billing-\(index)",
                                                                       content: content, trigger: trigger)))
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: paymentDate) else { break }
            reference = next
        }
        return result
    }

    /// 무료체험 종료 3일 전, 1일 전
    private func trialRequests(for sub: Subscription, hour: Int, now: Date) -> [(fireDate: Date, request: UNNotificationRequest)] {
        guard let trialEnd = sub.trialEndDate else { return [] }

        return trialReminderDays.compactMap { days in
            guard let schedule = fireSchedule(daysBefore: days, of: trialEnd, hour: hour),
                  schedule.fireDate > now
            else { return nil }

            let content = UNMutableNotificationContent()
            content.title = "무료체험 종료 예정"
            content.body = days == 1
                ? "\(sub.name) 무료체험이 내일 끝나요. 계속 쓸지 결정해보세요"
                : "\(sub.name) 무료체험이 \(days)일 후 끝나요. 계속 쓸지 결정해보세요"
            content.sound = .default
            content.userInfo = ["subscriptionID": sub.id.uuidString]
            let trigger = UNCalendarNotificationTrigger(dateMatching: schedule.components, repeats: false)
            return (schedule.fireDate, UNNotificationRequest(identifier: "\(sub.id.uuidString)-trial-\(days)",
                                                             content: content, trigger: trigger))
        }
    }

    /// 기준일 N일 전, 설정한 시각
    private func fireSchedule(daysBefore: Int, of date: Date, hour: Int) -> (fireDate: Date, components: DateComponents)? {
        guard let day = calendar.date(byAdding: .day, value: -daysBefore, to: date) else { return nil }
        var components = calendar.dateComponents([.year, .month, .day], from: day)
        components.hour = hour
        components.minute = 0
        guard let fireDate = calendar.date(from: components) else { return nil }
        return (fireDate, components)
    }

    /// "오늘이에요", "내일이에요", "3일 후예요"
    private static func relativeDay(_ days: Int) -> String {
        switch days {
        case 0:  "오늘이에요"
        case 1:  "내일이에요"
        default: "\(days)일 후예요"
        }
    }
}
