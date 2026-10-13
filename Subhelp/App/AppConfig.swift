import Foundation
import OSLog

/// 빌드 설정(Config/*.xcconfig) → Info.plist로 주입된 값을 읽는다.
/// 코드에 식별자·연락처를 하드코딩하지 않기 위한 단일 진입점.
enum AppConfig {
    static let appGroupID: String? = infoValue("AppGroupIdentifier")
    static let supportEmail: String? = infoValue("SupportEmail")
    static let privacyPolicyURL: URL? = infoValue("PrivacyPolicyURL").flatMap(URL.init(string:))
    /// Supabase 설정 — 둘 중 하나라도 비어 있으면 서버 기능을 끈다
    static let supabaseURL: URL? = infoValue("SupabaseURL").flatMap(URL.init(string:))
    static let supabaseAnonKey: String? = infoValue("SupabaseAnonKey")

    static var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "-"
        return "\(version) (\(build))"
    }

    /// 비어 있거나 치환되지 않은 값(`$(...)`)은 nil로 취급
    private static func infoValue(_ key: String) -> String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !trimmed.contains("$(") else { return nil }
        return trimmed
    }
}

extension Logger {
    static let app = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Subhelp", category: "app")
}
