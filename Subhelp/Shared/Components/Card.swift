import SwiftUI

/// 홈·상세 카드 (모서리 16pt)
struct Card<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}

/// VoiceOver 라벨 — "넷플릭스, 17,000원, 매월, 2일 후 결제"
enum SubscriptionAccessibility {
    static func spokenPrice(_ price: Decimal, _ currency: Currency) -> String {
        let number = price.formatted(.number.precision(.fractionLength(0...currency.fractionDigits)))
        switch currency {
        case .krw: return "\(number)원"
        case .usd: return "\(number)달러"
        }
    }

    static func label(_ sub: Subscription, days: Int?) -> String {
        var parts = [sub.name,
                     spokenPrice(sub.price, sub.currency),
                     sub.cycle.label(interval: sub.cycleInterval)]
        if let days { parts.append(DDay.spoken(days)) }
        return parts.joined(separator: ", ")
    }
}
