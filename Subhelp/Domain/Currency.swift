import Foundation

enum Currency: String, Codable, CaseIterable, Identifiable {
    case krw = "KRW"
    case usd = "USD"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .krw: "원 (KRW)"
        case .usd: "달러 (USD)"
        }
    }

    var fractionDigits: Int {
        switch self {
        case .krw: 0
        case .usd: 2
        }
    }
}
