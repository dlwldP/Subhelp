import Foundation

/// 금액 입력 규칙: 0원·음수 불가, 최대 9자리
enum PriceRule {
    static let maxValue: Decimal = 999_999_999

    enum Problem: Equatable {
        case notPositive
        case tooLarge
    }

    static func validate(_ price: Decimal) -> Problem? {
        if price <= 0 { return .notPositive }
        if price > maxValue { return .tooLarge }
        return nil
    }
}
