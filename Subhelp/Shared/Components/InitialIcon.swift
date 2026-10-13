import SwiftUI

/// 브랜드 로고 대신 쓰는 이니셜 + 색상 원형 아이콘
struct InitialIcon: View {
    let name: String
    let colorHex: String
    var size: CGFloat = 36

    private var initial: String {
        name.trimmingCharacters(in: .whitespaces).first.map { String($0).uppercased() } ?? "?"
    }

    var body: some View {
        Circle()
            .fill(Color(hex: colorHex).gradient)
            .frame(width: size, height: size)
            .overlay {
                Text(initial)
                    .font(.system(size: size * 0.45, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .accessibilityHidden(true)
    }
}
