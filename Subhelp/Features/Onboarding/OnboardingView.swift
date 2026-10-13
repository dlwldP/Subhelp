import SwiftUI

/// 첫 실행 온보딩 2장: 가치 소개 → 첫 구독 추가 유도.
/// 알림 권한은 여기서 묻지 않는다 (첫 구독 등록 직후 맥락과 함께 요청)
struct OnboardingView: View {
    @AppStorage(AppSettings.Key.hasCompletedOnboarding, store: AppSettings.store)
    private var hasCompletedOnboarding = false

    @State private var page = 0

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                introPage.tag(0)
                startPage.tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            VStack(spacing: 12) {
                if page == 0 {
                    Button { withAnimation { page = 1 } } label: {
                        Text("다음").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button { finish(addFirst: true) } label: {
                        Text("구독 추가").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    Button("나중에 할게요") { finish(addFirst: false) }
                        .font(.subheadline)
                }
            }
            .controlSize(.large)
            .buttonBorderShape(.roundedRectangle(radius: 12))
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .interactiveDismissDisabled()
    }

    private var introPage: some View {
        VStack(alignment: .leading, spacing: 24) {
            Spacer()
            Image(systemName: "creditcard.and.123")
                .font(.system(size: 56))
                .foregroundStyle(Color.accentColor)
            Text("매달 나가는 구독,\n얼마인지 알고 계세요?")
                .font(.largeTitle.bold())
            VStack(alignment: .leading, spacing: 16) {
                FeatureRow(symbol: "sum", text: "이번 달 결제 예정액을 한눈에 보여드려요")
                FeatureRow(symbol: "bell.badge", text: "결제 전에 먼저 알려드려요")
                FeatureRow(symbol: "gift", text: "무료체험이 끝나기 전에도 챙겨드려요")
                FeatureRow(symbol: "lock.iphone", text: "계정 없이, 데이터는 내 폰에만 저장돼요")
            }
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 24)
    }

    private var startPage: some View {
        VStack(alignment: .leading, spacing: 24) {
            Spacer()
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(Color.accentColor)
            Text("첫 구독을\n추가해볼까요?")
                .font(.largeTitle.bold())
            Text("자주 쓰는 서비스를 고르고 금액만 입력하면 끝이에요.")
                .font(.body)
                .foregroundStyle(.secondary)
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
    }

    private func finish(addFirst: Bool) {
        AppRouter.shared.shouldAddAfterOnboarding = addFirst
        hasCompletedOnboarding = true
    }
}

private struct FeatureRow: View {
    let symbol: String
    let text: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)
                .accessibilityHidden(true)
            Text(text)
                .font(.body)
        }
    }
}
