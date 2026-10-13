import Foundation
import UserNotifications

/// 결제일 로컬 알림.
///
/// - 구독마다 다음 결제 2회분만 예약한다 (iOS 대기 알림 한도 64개)
/// - 재예약 시점: 앱 실행·활성화, 구독 추가/수정/삭제
/// - 전부 지우고 다시 거는 방식 → 단순하고 버그가 적다. 구독 수가 적어 MVP는 이걸로 충분
@MainActor
final class NotificationService {
    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()
    private let calendar = Calendar.current
    private let billing = BillingCalculator()

    private let pendingLimit = 64
    private let occurrencesPerSubscription = 2
    private let notifyHour = 9

    private init() {}

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    @discardableResult
    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    /// 아직 묻지 않았을 때만 권한을 요청한다. (첫 구독 추가 직후 호출 — 첫 실행에 바로 띄우지 않는다)
    func requestAuthorizationIfNeeded() async {
        if await authorizationStatus() == .notDetermined {
            await requestAuthorization()
        }
    }

    func rescheduleAll(_ subscriptions: [Subscription], now: Date = .now) async {
        center.removeAllPendingNotificationRequests()

        let status = await authorizationStatus()
        guard status == .authorized || status == .provisional else { return }

        var pending: [(fireDate: Date, request: UNNotificationRequest)] = []
        for sub in subscriptions where sub.isActive {
            pending += billingRequests(for: sub, now: now)
            if let trial = trialRequest(for: sub, now: now) { pending.append(trial) }
        }

        // 한도를 넘으면 가까운 알림부터 남긴다
        for item in pending.sorted(by: { $0.fireDate < $1.fireDate }).prefix(pendingLimit) {
            try? await center.add(item.request)
        }
    }

    // MARK: - Private

    private func billingRequests(for sub: Subscription, now: Date) -> [(fireDate: Date, request: UNNotificationRequest)] {
        guard let days = sub.notifyDaysBefore else { return [] }

        var result: [(fireDate: Date, request: UNNotificationRequest)] = []
        var reference = now
        for index in 0..<occurrencesPerSubscription {
            let billingDate = billing.nextBillingDate(start: sub.startDate, cycle: sub.cycle,
                                                      interval: sub.cycleInterval, from: reference)
            if let schedule = fireSchedule(daysBefore: days, of: billingDate), schedule.fireDate > now {
                let content = UNMutableNotificationContent()
                content.title = "\(sub.name) 결제 예정"
                content.body = days == 0
                    ? "오늘 \(sub.price.currencyText(sub.currency)) 결제돼요"
                    : "\(days)일 후 \(sub.price.currencyText(sub.currency)) 결제돼요"
                content.sound = .default
                let trigger = UNCalendarNotificationTrigger(dateMatching: schedule.components, repeats: false)
                result.append((schedule.fireDate, UNNotificationRequest(identifier: "\(sub.id.uuidString)-billing-\(index)",
                                                               content: content, trigger: trigger)))
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: billingDate) else { break }
            reference = next
        }
        return result
    }

    /// 무료체험 종료 하루 전 알림
    private func trialRequest(for sub: Subscription, now: Date) -> (fireDate: Date, request: UNNotificationRequest)? {
        guard let trialEnd = sub.trialEndDate,
              let schedule = fireSchedule(daysBefore: 1, of: trialEnd),
              schedule.fireDate > now
        else { return nil }

        let content = UNMutableNotificationContent()
        content.title = "\(sub.name) 무료체험 종료 예정"
        content.body = "내일 체험이 끝나요. 계속 쓰지 않을 거라면 오늘 해지하세요."
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(dateMatching: schedule.components, repeats: false)
        return (schedule.fireDate, UNNotificationRequest(identifier: "\(sub.id.uuidString)-trial",
                                                content: content, trigger: trigger))
    }

    /// 기준일 N일 전 오전 9시
    private func fireSchedule(daysBefore: Int, of date: Date) -> (fireDate: Date, components: DateComponents)? {
        guard let day = calendar.date(byAdding: .day, value: -daysBefore, to: date) else { return nil }
        var components = calendar.dateComponents([.year, .month, .day], from: day)
        components.hour = notifyHour
        components.minute = 0
        guard let fireDate = calendar.date(from: components) else { return nil }
        return (fireDate, components)
    }
}
