import Foundation

extension Decimal {
    func currencyText(_ currency: Currency = .krw) -> String {
        formatted(.currency(code: currency.rawValue).precision(.fractionLength(currency.fractionDigits)))
    }

    /// 환율 환산 등 추정 금액이면 "≈ ₩13,986"
    func currencyText(_ currency: Currency = .krw, estimated: Bool) -> String {
        estimated ? "≈ " + currencyText(currency) : currencyText(currency)
    }

    var doubleValue: Double {
        NSDecimalNumber(decimal: self).doubleValue
    }
}

enum DDay {
    static func text(_ days: Int) -> String {
        switch days {
        case ..<0: "D+\(-days)"
        case 0:    "오늘"
        default:   "D-\(days)"
        }
    }

    /// VoiceOver용 — "오늘 결제", "내일 결제", "2일 후 결제"
    static func spoken(_ days: Int, suffix: String = "결제") -> String {
        switch days {
        case ..<0: "\(-days)일 전 \(suffix)"
        case 0:    "오늘 \(suffix)"
        case 1:    "내일 \(suffix)"
        default:   "\(days)일 후 \(suffix)"
        }
    }

    enum Urgency {
        case imminent   // 오늘·내일 → 강조색(오렌지)
        case soon       // 7일 이내 → 보조색
        case later      // 그 외 → 회색
    }

    static func urgency(_ days: Int) -> Urgency {
        switch days {
        case ...1: .imminent
        case ...7: .soon
        default:   .later
        }
    }
}

extension Subscription {
    /// "₩17,000 / 월", "₩30,000 / 3개월"
    var priceWithCycleText: String {
        "\(price.currencyText(currency)) / \(cycle.shortLabel(interval: cycleInterval))"
    }
}
