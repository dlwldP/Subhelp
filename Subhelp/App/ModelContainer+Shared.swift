import Foundation
import OSLog
import SwiftData

/// 앱과 위젯이 함께 쓰는 ModelContainer (App Group 컨테이너에 저장)
enum SharedModelContainer {
    static let shared: ModelContainer = makeContainer()

    private static func makeContainer() -> ModelContainer {
        let schema = Schema([Subscription.self, DeletionTombstone.self])

        if let groupID = AppConfig.appGroupID {
            let config = ModelConfiguration(schema: schema, groupContainer: .identifier(groupID))
            do {
                return try ModelContainer(for: schema, configurations: [config])
            } catch {
                Logger.app.error("App Group 컨테이너 생성 실패(\(groupID, privacy: .public)): \(error.localizedDescription, privacy: .public)")
            }
        } else {
            Logger.app.warning("APP_GROUP_ID가 설정되지 않았습니다. 위젯과 데이터가 공유되지 않습니다. (Config/Local.xcconfig 확인)")
        }

        // App Group 미설정(개발 초기 등) → 앱 전용 저장소로 동작
        do {
            return try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema)])
        } catch {
            fatalError("ModelContainer 생성 실패: \(error)")
        }
    }
}
