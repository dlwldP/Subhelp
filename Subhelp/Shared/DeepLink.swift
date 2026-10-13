import Foundation

/// 위젯·알림 → 앱 화면 이동용 URL (`subhelp://`)
enum DeepLink {
    static let scheme = "subhelp"
    static let home = URL(string: "\(scheme)://home")!

    static func subscription(_ id: UUID) -> URL {
        URL(string: "\(scheme)://subscription/\(id.uuidString)")!
    }

    enum Destination: Equatable {
        case home
        case subscription(UUID)
    }

    static func parse(_ url: URL) -> Destination? {
        guard url.scheme == scheme else { return nil }
        switch url.host {
        case "subscription":
            return UUID(uuidString: url.lastPathComponent).map(Destination.subscription)
        default:
            return .home
        }
    }
}
