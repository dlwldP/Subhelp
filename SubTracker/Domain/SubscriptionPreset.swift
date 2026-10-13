import Foundation

enum SubscriptionCategory {
    static let all = ["OTT", "음악", "쇼핑", "생산성", "클라우드", "게임", "교육", "뉴스", "기타"]
    static let fallback = "기타"
}

/// 추가 화면의 프리셋.
/// - 브랜드 로고는 쓰지 않는다 (상표 문제) → 이니셜 + 색상 원형 아이콘
/// - 가격은 넣지 않는다 (요금이 수시로 바뀜) → 사용자가 입력
struct SubscriptionPreset: Identifiable, Hashable {
    var id: String { name }
    let name: String
    let category: String
    let cycle: BillingCycle
    let colorHex: String

    static let all: [SubscriptionPreset] = [
        .init(name: "넷플릭스", category: "OTT", cycle: .monthly, colorHex: "#D64545"),
        .init(name: "유튜브 프리미엄", category: "OTT", cycle: .monthly, colorHex: "#E0603A"),
        .init(name: "티빙", category: "OTT", cycle: .monthly, colorHex: "#C2456B"),
        .init(name: "디즈니+", category: "OTT", cycle: .monthly, colorHex: "#3C5BA9"),
        .init(name: "웨이브", category: "OTT", cycle: .monthly, colorHex: "#3D7BD9"),
        .init(name: "쿠팡플레이", category: "OTT", cycle: .monthly, colorHex: "#4A6FE3"),
        .init(name: "쿠팡 와우", category: "쇼핑", cycle: .monthly, colorHex: "#2F8FD8"),
        .init(name: "네이버플러스 멤버십", category: "쇼핑", cycle: .monthly, colorHex: "#2FA866"),
        .init(name: "스포티파이", category: "음악", cycle: .monthly, colorHex: "#2E9E5B"),
        .init(name: "멜론", category: "음악", cycle: .monthly, colorHex: "#3BB273"),
        .init(name: "애플 뮤직", category: "음악", cycle: .monthly, colorHex: "#E5566B"),
        .init(name: "iCloud+", category: "클라우드", cycle: .monthly, colorHex: "#5B8DEF"),
        .init(name: "구글 One", category: "클라우드", cycle: .monthly, colorHex: "#4C8BF5"),
        .init(name: "ChatGPT", category: "생산성", cycle: .monthly, colorHex: "#4A9C88"),
        .init(name: "노션", category: "생산성", cycle: .monthly, colorHex: "#5F5F5F"),
        .init(name: "닌텐도 스위치 온라인", category: "게임", cycle: .yearly, colorHex: "#D9534F"),
    ]
}
