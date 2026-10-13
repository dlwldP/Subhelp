import AuthenticationServices
import SwiftUI

/// 설정 > 계정·동기화. Supabase가 설정되지 않은 빌드에서는 보이지 않는다.
struct AccountSection: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var isConfirmingSignOut = false
    @State private var isConfirmingDelete = false

    private let account = AccountService.shared

    var body: some View {
        if account.isAvailable {
            Section {
                if account.isSignedIn {
                    signedInRows
                } else {
                    SignInWithAppleButton(.signIn) { request in
                        account.prepareAppleRequest(request)
                    } onCompletion: { result in
                        Task { await account.handleAppleSignIn(result) }
                    }
                    .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                    .frame(height: 44)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }
                if let message = account.errorMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            } header: {
                Text("계정·동기화")
            } footer: {
                Text(account.isSignedIn
                     ? "로그아웃해도 이 기기의 구독은 그대로 남아요. 계정을 삭제하면 서버에 백업된 구독이 모두 지워져요."
                     : "Apple로 로그인하면 구독 목록이 서버에 백업되고 다른 기기와 동기화돼요. 로그인하지 않아도 모든 기능을 쓸 수 있어요.")
            }
        }
    }

    @ViewBuilder
    private var signedInRows: some View {
        LabeledContent("계정", value: account.email ?? "Apple 계정")
        LabeledContent("마지막 동기화", value: lastSyncText)

        Button {
            Task { await account.sync() }
        } label: {
            HStack {
                Text("지금 동기화")
                Spacer()
                if account.syncState == .syncing { ProgressView() }
            }
        }
        .disabled(account.syncState == .syncing)

        if case .failed(let message) = account.syncState {
            Text(message)
                .font(.footnote)
                .foregroundStyle(.red)
        }

        Button("로그아웃") { isConfirmingSignOut = true }
            .confirmationDialog("로그아웃할까요?", isPresented: $isConfirmingSignOut, titleVisibility: .visible) {
                Button("로그아웃") { Task { await account.signOut() } }
            } message: {
                Text("이 기기의 구독은 그대로 남고, 더 이상 서버와 동기화되지 않아요.")
            }

        Button("계정 삭제", role: .destructive) { isConfirmingDelete = true }
            .confirmationDialog("계정을 삭제할까요?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
                Button("계정 삭제", role: .destructive) { Task { _ = await account.deleteAccount() } }
            } message: {
                Text("서버에 백업된 구독과 계정 정보가 모두 지워지고 되돌릴 수 없어요. 이 기기의 구독은 남아요.")
            }
    }

    private var lastSyncText: String {
        guard let date = account.lastSyncedAt else { return "아직 없음" }
        return date.formatted(.relative(presentation: .named))
    }
}
