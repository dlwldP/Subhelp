import Foundation
import Observation

/// 편집 폼 상태. 저장 전까지는 @Model을 건드리지 않도록 별도 객체로 둔다.
@Observable
final class SubscriptionDraft {
    var name = ""
    var price: Decimal = 0
    var currency: Currency = AppSettings.defaultCurrency
    var cycle: BillingCycle = .monthly
    var interval = 1
    var startDate = Calendar.current.startOfDay(for: .now)
    var category = SubscriptionCategory.fallback
    var colorHex = ColorPalette.hexes[0]
    var notifyDaysBefore: Int? = AppSettings.defaultNotifyDays
    var isActive = true
    var hasTrial = false
    var trialEndDate = Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now
    var memo = ""

    init() {}

    convenience init(preset: SubscriptionPreset) {
        self.init()
        name = preset.name
        category = preset.category
        cycle = preset.cycle
        colorHex = preset.colorHex
    }

    convenience init(subscription sub: Subscription) {
        self.init()
        name = sub.name
        price = sub.price
        currency = sub.currency
        cycle = sub.cycle
        interval = sub.cycleInterval
        startDate = sub.startDate
        category = sub.category
        colorHex = sub.colorHex
        notifyDaysBefore = sub.notifyDaysBefore
        isActive = sub.isActive
        hasTrial = sub.trialEndDate != nil
        trialEndDate = sub.trialEndDate ?? trialEndDate
        memo = sub.memo
    }

    var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var isPriceValid: Bool { price > 0 }

    var isValid: Bool { !trimmedName.isEmpty && isPriceValid }

    func apply(to sub: Subscription) {
        sub.name = trimmedName
        sub.price = price
        sub.currency = currency
        sub.cycle = cycle
        sub.cycleInterval = max(1, interval)
        sub.startDate = Calendar.current.startOfDay(for: startDate)
        sub.category = category
        sub.colorHex = colorHex
        sub.notifyDaysBefore = notifyDaysBefore
        sub.isActive = isActive
        sub.trialEndDate = hasTrial ? Calendar.current.startOfDay(for: trialEndDate) : nil
        sub.memo = memo.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func makeSubscription() -> Subscription {
        let sub = Subscription(name: trimmedName, price: price, cycle: cycle, startDate: startDate)
        apply(to: sub)
        return sub
    }
}
