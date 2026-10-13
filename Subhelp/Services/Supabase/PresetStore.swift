import Foundation
import Observation
import OSLog
import Supabase

/// 추가 화면 프리셋. 서버(`public.presets`)에서 받아 캐시하고, 서버가 없거나 실패하면 번들 기본값을 쓴다.
/// 앱을 업데이트하지 않고도 프리셋을 추가·수정할 수 있다.
@MainActor
@Observable
final class PresetStore {
    static let shared = PresetStore()

    private(set) var presets: [SubscriptionPreset]

    @ObservationIgnored private let cacheKey = "remotePresetsCache"

    private init() {
        presets = SubscriptionPreset.all
        if let data = AppSettings.store.data(forKey: cacheKey),
           let cached = try? JSONDecoder().decode([SubscriptionPreset].self, from: data),
           !cached.isEmpty {
            presets = cached
        }
    }

    func refresh() async {
        guard let client = SupabaseService.client else { return }
        do {
            let rows: [RemotePreset] = try await client.from("presets")
                .select("name,category,cycle,color_hex")
                .order("sort_order")
                .execute()
                .value
            let fetched = rows.map(\.preset)
            guard !fetched.isEmpty else { return }
            presets = fetched
            if let data = try? JSONEncoder().encode(fetched) {
                AppSettings.store.set(data, forKey: cacheKey)
            }
        } catch {
            Logger.app.error("프리셋을 받지 못함: \(error.localizedDescription, privacy: .public)")
        }
    }
}
