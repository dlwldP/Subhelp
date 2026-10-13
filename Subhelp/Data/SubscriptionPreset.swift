import Foundation

enum SubscriptionCategory {
    static let all = ["영상", "음악", "쇼핑·멤버십", "생산성·업무", "AI", "클라우드·저장공간", "게임", "교육", "뉴스·도서", "기타"]
    static let fallback = "기타"
}

/// 추가 화면의 프리셋 — 이름, 카테고리, 대표 색상만 제공한다.
/// - 브랜드 로고는 쓰지 않는다 (상표 문제) → 이니셜 + 색상 원형 아이콘
/// - 가격은 넣지 않는다 (요금 변경이 잦고 요금제마다 다름) → 사용자가 입력
struct SubscriptionPreset: Identifiable, Hashable {
    var id: String { name }
    let name: String
    let category: String
    let cycle: BillingCycle
    let colorHex: String

    static let all: [SubscriptionPreset] = [
        .init(name: "넷플릭스", category: "영상", cycle: .monthly, colorHex: "#D64545"),
        .init(name: "유튜브 프리미엄", category: "영상", cycle: .monthly, colorHex: "#E0603A"),
        .init(name: "티빙", category: "영상", cycle: .monthly, colorHex: "#C2456B"),
        .init(name: "디즈니+", category: "영상", cycle: .monthly, colorHex: "#3C5BA9"),
        .init(name: "웨이브", category: "영상", cycle: .monthly, colorHex: "#3D7BD9"),
        .init(name: "쿠팡플레이", category: "영상", cycle: .monthly, colorHex: "#4A6FE3"),
        .init(name: "스포티파이", category: "음악", cycle: .monthly, colorHex: "#2E9E5B"),
        .init(name: "멜론", category: "음악", cycle: .monthly, colorHex: "#3BB273"),
        .init(name: "애플 뮤직", category: "음악", cycle: .monthly, colorHex: "#E5566B"),
        .init(name: "쿠팡 와우", category: "쇼핑·멤버십", cycle: .monthly, colorHex: "#2F8FD8"),
        .init(name: "네이버플러스 멤버십", category: "쇼핑·멤버십", cycle: .monthly, colorHex: "#2FA866"),
        .init(name: "노션", category: "생산성·업무", cycle: .monthly, colorHex: "#5F5F5F"),
        .init(name: "피그마", category: "생산성·업무", cycle: .monthly, colorHex: "#8A5BD6"),
        .init(name: "ChatGPT", category: "AI", cycle: .monthly, colorHex: "#4A9C88"),
        .init(name: "Claude", category: "AI", cycle: .monthly, colorHex: "#C9733E"),
        .init(name: "iCloud+", category: "클라우드·저장공간", cycle: .monthly, colorHex: "#5B8DEF"),
        .init(name: "구글 One", category: "클라우드·저장공간", cycle: .monthly, colorHex: "#4C8BF5"),
        .init(name: "닌텐도 스위치 온라인", category: "게임", cycle: .yearly, colorHex: "#D9534F"),
        .init(name: "밀리의 서재", category: "뉴스·도서", cycle: .monthly, colorHex: "#E5A23A"),
    ]

    /// 카테고리 순서대로 묶은 프리셋 (그리드 섹션용)
    static func grouped(_ presets: [SubscriptionPreset]) -> [PresetSection] {
        SubscriptionCategory.all.compactMap { category in
            let items = presets.filter { $0.category == category }
            return items.isEmpty ? nil : PresetSection(category: category, presets: items)
        }
    }
}

struct PresetSection: Identifiable {
    let category: String
    let presets: [SubscriptionPreset]
    var id: String { category }
}
