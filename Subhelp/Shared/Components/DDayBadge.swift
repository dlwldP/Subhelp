import SwiftUI

/// D-day 배지 — 색과 텍스트를 함께 써서 색만으로 정보를 구분하지 않는다
struct DDayBadge: View {
    let days: Int

    private var tint: Color {
        switch DDay.urgency(days) {
        case .imminent: .orange
        case .soon:     .accentColor
        case .later:    .gray
        }
    }

    var body: some View {
        Text(DDay.text(days))
            .font(.caption.weight(.semibold))
            .monospacedDigit()
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .foregroundStyle(tint)
            .background(tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 6))
            .accessibilityLabel(DDay.spoken(days))
    }
}
