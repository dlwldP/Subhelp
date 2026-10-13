import SwiftUI

extension Color {
    /// "#RRGGBB" 형식. 파싱 실패 시 회색.
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "#", with: "")
        guard cleaned.count == 6, let value = UInt32(cleaned, radix: 16) else {
            self = .gray
            return
        }
        self.init(red: Double((value >> 16) & 0xFF) / 255,
                  green: Double((value >> 8) & 0xFF) / 255,
                  blue: Double(value & 0xFF) / 255)
    }
}

enum ColorPalette {
    static let hexes = ["#5B8DEF", "#D64545", "#E0603A", "#E5A23A", "#2E9E5B",
                        "#2FA8A8", "#3C5BA9", "#8A5BD6", "#C2456B", "#5F5F5F"]
}
