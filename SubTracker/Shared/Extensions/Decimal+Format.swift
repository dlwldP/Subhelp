import Foundation

extension Decimal {
    func currencyText(_ currency: Currency = .krw) -> String {
        formatted(.currency(code: currency.rawValue).precision(.fractionLength(currency.fractionDigits)))
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
}
