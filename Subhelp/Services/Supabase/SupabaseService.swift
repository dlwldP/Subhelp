import Foundation
import Supabase

/// Supabase 클라이언트. `SUPABASE_URL`·`SUPABASE_ANON_KEY`가 비어 있으면 nil → 서버 기능이 꺼지고 기기 저장만으로 동작한다.
enum SupabaseService {
    static let client: SupabaseClient? = {
        guard let url = AppConfig.supabaseURL, let key = AppConfig.supabaseAnonKey else { return nil }
        return SupabaseClient(supabaseURL: url, supabaseKey: key)
    }()

    static var isConfigured: Bool { client != nil }
}

/// 서버 날짜 형식 ↔ Date
/// - `date` 컬럼(첫 결제일 등): "2026-10-13" — 기기 시간대의 그 날짜 자정
/// - `timestamptz` 컬럼(수정 시각 등): ISO 8601 (UTC)
enum SupabaseDate {
    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let timestampFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let timestampFormatterNoFraction: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static func dayString(_ date: Date) -> String {
        dayFormatter.string(from: date)
    }

    static func day(from string: String) -> Date? {
        dayFormatter.date(from: String(string.prefix(10)))
    }

    static func timestampString(_ date: Date) -> String {
        timestampFormatter.string(from: date.truncatedToMilliseconds)
    }

    static func timestamp(from string: String) -> Date? {
        let normalized = normalizeFraction(string)
        return timestampFormatter.date(from: normalized) ?? timestampFormatterNoFraction.date(from: normalized)
    }

    /// Postgres는 마이크로초(6자리)까지 돌려줄 수 있어 3자리로 맞춘다
    private static func normalizeFraction(_ string: String) -> String {
        guard let dot = string.firstIndex(of: ".") else { return string }
        let fractionStart = string.index(after: dot)
        let fractionEnd = string[fractionStart...].firstIndex { !$0.isNumber } ?? string.endIndex
        let digits = string[fractionStart..<fractionEnd]
        let millis = String((digits + "000").prefix(3))
        return String(string[..<fractionStart]) + millis + String(string[fractionEnd...])
    }
}
