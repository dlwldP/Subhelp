import Foundation

/// 사용자 설정. App Group UserDefaults에 저장해서 위젯도 같은 값을 쓴다.
enum AppSettings {
    enum Key {
        static let defaultCurrency = "defaultCurrency"
        static let usdToKrwRate = "usdToKrwRate"
        static let defaultNotifyDays = "defaultNotifyDays"
        static let notifyHour = "notifyHour"
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let hasRequestedReview = "hasRequestedReview"
    }

    /// 실시간 환율은 MVP 범위 밖 → 사용자가 직접 입력 (초기값)
    static let defaultUSDRate: Double = 1400
    /// 알림 기본값 (-1 = 끔)
    static let defaultNotifyDaysValue = 1
    static let notifyOff = -1
    static let defaultNotifyHour = 9

    static let store: UserDefaults = AppConfig.appGroupID.flatMap(UserDefaults.init(suiteName:)) ?? .standard

    static var usdToKrw: Decimal {
        let value = store.object(forKey: Key.usdToKrwRate) as? Double ?? defaultUSDRate
        return decimal(value > 0 ? value : defaultUSDRate)
    }

    static var defaultCurrency: Currency {
        store.string(forKey: Key.defaultCurrency).flatMap(Currency.init(rawValue:)) ?? .krw
    }

    static var defaultNotifyDays: Int? {
        let value = store.object(forKey: Key.defaultNotifyDays) as? Int ?? defaultNotifyDaysValue
        return value < 0 ? nil : value
    }

    static var notifyHour: Int {
        let value = store.object(forKey: Key.notifyHour) as? Int ?? defaultNotifyHour
        return (0...23).contains(value) ? value : defaultNotifyHour
    }

    /// Double → Decimal 변환 시 이진 부동소수 잡음(1380.5000000001)을 피하려고 문자열을 거친다
    static func decimal(_ value: Double) -> Decimal {
        Decimal(string: String(value)) ?? Decimal(value)
    }
}
