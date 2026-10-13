import Foundation
import SwiftData

/// 모든 프로퍼티에 기본값을 둔다.
/// CloudKit 동기화(MVP 이후)를 붙일 때 필수 조건이라 지금 해두면 마이그레이션이 필요 없다.
@Model
final class Subscription {
    var id: UUID = UUID()
    var name: String = ""
    var price: Decimal = 0
    var currencyCode: String = Currency.krw.rawValue
    var cycleRaw: String = BillingCycle.monthly.rawValue   // #Predicate에서 enum을 직접 쓰기 까다로워 raw로 저장
    var cycleInterval: Int = 1                             // 3개월마다 → monthly + 3
    var startDate: Date = Date.now
    var category: String = SubscriptionCategory.fallback
    var colorHex: String = "#5B8DEF"
    var notifyDaysBefore: Int? = 1                         // nil = 알림 끔
    var isActive: Bool = true
    var trialEndDate: Date? = nil
    var memo: String = ""
    var createdAt: Date = Date.now

    var cycle: BillingCycle {
        get { BillingCycle(rawValue: cycleRaw) ?? .monthly }
        set { cycleRaw = newValue.rawValue }
    }

    var currency: Currency {
        get { Currency(rawValue: currencyCode) ?? .krw }
        set { currencyCode = newValue.rawValue }
    }

    var plan: BillingPlan {
        BillingPlan(price: price, currency: currency, cycle: cycle,
                    interval: cycleInterval, startDate: startDate)
    }

    init(name: String, price: Decimal, cycle: BillingCycle, startDate: Date) {
        self.name = name
        self.price = price
        self.cycleRaw = cycle.rawValue
        self.startDate = startDate
    }
}
