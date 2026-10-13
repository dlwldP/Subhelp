import Foundation

enum BillingCycle: String, Codable, CaseIterable, Identifiable {
    case weekly, monthly, yearly

    var id: String { rawValue }

    var component: Calendar.Component {
        switch self {
        case .weekly:  .weekOfYear
        case .monthly: .month
        case .yearly:  .year
        }
    }

    var displayName: String {
        switch self {
        case .weekly:  "주"
        case .monthly: "월"
        case .yearly:  "년"
        }
    }

    /// 금액 뒤에 붙는 짧은 표기 — "월", "3개월", "2주"
    func shortLabel(interval: Int) -> String {
        let interval = max(1, interval)
        switch self {
        case .weekly:  return interval == 1 ? "주" : "\(interval)주"
        case .monthly: return interval == 1 ? "월" : "\(interval)개월"
        case .yearly:  return interval == 1 ? "년" : "\(interval)년"
        }
    }

    /// "매월", "3개월마다", "2주마다" 같은 주기 표기
    func label(interval: Int) -> String {
        let interval = max(1, interval)
        switch self {
        case .weekly:  return interval == 1 ? "매주" : "\(interval)주마다"
        case .monthly: return interval == 1 ? "매월" : "\(interval)개월마다"
        case .yearly:  return interval == 1 ? "매년" : "\(interval)년마다"
        }
    }
}
