import AuthenticationServices
import CryptoKit
import Foundation
import Observation
import OSLog
import Supabase

/// 선택형 계정(Apple 로그인)과 서버 동기화 상태.
/// 로그인하지 않아도 모든 기능이 기기 저장만으로 동작한다.
@MainActor
@Observable
final class AccountService {
    static let shared = AccountService()

    enum SyncState: Equatable {
        case idle
        case syncing
        case failed(String)
    }

    private(set) var userID: UUID?
    private(set) var email: String?
    private(set) var syncState: SyncState = .idle
    private(set) var lastSyncedAt: Date?
    private(set) var errorMessage: String?

    var isAvailable: Bool { SupabaseService.isConfigured }
    var isSignedIn: Bool { userID != nil }

    @ObservationIgnored private var currentNonce: String?
    @ObservationIgnored private var authTask: Task<Void, Never>?
    @ObservationIgnored private var pendingSync: Task<Void, Never>?

    private let lastSyncedKey = "lastSyncedAt"

    private init() {
        lastSyncedAt = AppSettings.store.object(forKey: lastSyncedKey) as? Date
    }

    /// 앱 실행 시 한 번 — 저장된 세션을 복원하고 로그인 상태 변화를 구독한다
    func start() {
        guard authTask == nil, let client = SupabaseService.client else { return }
        authTask = Task { [weak self] in
            for await (event, session) in client.auth.authStateChanges {
                guard let self else { return }
                self.update(session: session)
                if event == .signedIn || (event == .initialSession && session != nil) {
                    await self.sync()
                }
            }
        }
    }

    // MARK: - Apple 로그인

    func prepareAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = Self.randomNonce()
        currentNonce = nonce
        request.requestedScopes = [.email]
        request.nonce = Self.sha256(nonce)
    }

    func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) async {
        errorMessage = nil
        switch result {
        case .success(let authorization):
            guard let client = SupabaseService.client,
                  let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8),
                  let nonce = currentNonce
            else {
                errorMessage = "Apple 로그인 정보를 받지 못했어요. 다시 시도해주세요."
                return
            }
            do {
                let session = try await client.auth.signInWithIdToken(
                    credentials: OpenIDConnectCredentials(provider: .apple, idToken: idToken, nonce: nonce)
                )
                update(session: session)
            } catch {
                Logger.app.error("Supabase 로그인 실패: \(error.localizedDescription, privacy: .public)")
                errorMessage = "로그인하지 못했어요. 잠시 후 다시 시도해주세요."
            }
        case .failure(let error):
            if (error as? ASAuthorizationError)?.code == .canceled { return }
            errorMessage = "로그인하지 못했어요. 잠시 후 다시 시도해주세요."
        }
    }

    /// 로그아웃 — 이 기기의 구독은 그대로 남는다
    func signOut() async {
        guard let client = SupabaseService.client else { return }
        try? await client.auth.signOut()
        clearLocalAccountState()
    }

    /// 계정 삭제 — 서버의 계정과 백업 데이터를 모두 지운다. 이 기기의 구독은 남는다.
    /// `authorizationCode`: 삭제 직전 Apple 재인증으로 받은 코드. Edge Function이 이걸로 Apple 토큰을 철회한다
    func deleteAccount(authorizationCode: String?) async -> Bool {
        guard let client = SupabaseService.client else { return false }
        errorMessage = nil
        do {
            let response: DeleteAccountResponse = try await client.functions.invoke(
                "delete-account",
                options: FunctionInvokeOptions(body: DeleteAccountRequest(authorizationCode: authorizationCode))
            )
            if !response.appleTokenRevoked {
                Logger.app.warning("계정은 삭제됐지만 Apple 토큰 철회는 실패함 (Edge Function 로그 확인)")
            }
        } catch {
            // Edge Function을 아직 배포하지 않은 경우 등: DB 함수로 계정만 삭제 (Apple 토큰 철회는 생략됨)
            Logger.app.error("delete-account 함수 호출 실패, DB 함수로 대체: \(error.localizedDescription, privacy: .public)")
            do {
                try await client.rpc("delete_account").execute()
            } catch {
                Logger.app.error("계정 삭제 실패: \(error.localizedDescription, privacy: .public)")
                errorMessage = "계정을 삭제하지 못했어요. 네트워크를 확인하고 다시 시도해주세요."
                return false
            }
        }
        try? await client.auth.signOut()
        clearLocalAccountState()
        return true
    }

    /// 계정 삭제 전 Apple 재인증 결과 → authorizationCode. 사용자가 취소했는지도 함께 돌려준다
    static func authorizationCode(from result: Result<ASAuthorization, Error>) -> (code: String?, isCanceled: Bool) {
        switch result {
        case .success(let authorization):
            let credential = authorization.credential as? ASAuthorizationAppleIDCredential
            let code = credential?.authorizationCode.flatMap { String(data: $0, encoding: .utf8) }
            return (code, false)
        case .failure(let error):
            return (nil, (error as? ASAuthorizationError)?.code == .canceled)
        }
    }

    // MARK: - 동기화

    /// 데이터 변경 직후 호출 — 연속 수정을 묶어 잠시 뒤 한 번만 동기화한다
    func requestSync() {
        guard isSignedIn else { return }
        pendingSync?.cancel()
        pendingSync = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            await self?.sync()
        }
    }

    func sync() async {
        guard let client = SupabaseService.client, let userID, syncState != .syncing else { return }
        syncState = .syncing
        let context = SharedModelContainer.shared.mainContext
        do {
            try await SyncService.run(client: client, userID: userID, context: context)
            lastSyncedAt = .now
            AppSettings.store.set(lastSyncedAt, forKey: lastSyncedKey)
            syncState = .idle
            await SubscriptionSync.refresh(using: context)
        } catch {
            Logger.app.error("동기화 실패: \(error.localizedDescription, privacy: .public)")
            syncState = .failed("동기화하지 못했어요. 네트워크를 확인해주세요.")
        }
    }

    // MARK: - Private

    private func update(session: Session?) {
        userID = session?.user.id
        email = session?.user.email
    }

    private func clearLocalAccountState() {
        userID = nil
        email = nil
        syncState = .idle
        lastSyncedAt = nil
        AppSettings.store.removeObject(forKey: lastSyncedKey)
        // 로그아웃 후에는 지운 기록을 서버에 보낼 일이 없다
        let context = SharedModelContainer.shared.mainContext
        try? context.delete(model: DeletionTombstone.self)
        try? context.save()
    }

    private static func randomNonce(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var bytes = [UInt8](repeating: 0, count: length)
        if SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) != errSecSuccess {
            return UUID().uuidString + UUID().uuidString
        }
        return String(bytes.map { charset[Int($0) % charset.count] })
    }

    private static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

private struct DeleteAccountRequest: Encodable, Sendable {
    let authorizationCode: String?
}

private struct DeleteAccountResponse: Decodable, Sendable {
    let deleted: Bool
    let appleTokenRevoked: Bool
}
