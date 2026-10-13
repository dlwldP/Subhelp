# Subhelp — 구독 관리 iOS 앱

**흩어진 구독 결제를 한곳에 모아, 언제·얼마가 빠져나가는지 미리 알려주는 앱.**
계정·서버 없이 로컬 우선(SwiftData)으로 동작하고, 동기화는 MVP 이후에 붙인다.

| 항목 | 결정 |
|---|---|
| 최소 타깃 | iOS 17+ |
| UI | SwiftUI |
| 저장소 | SwiftData (App Group 컨테이너 → 위젯과 공유) |
| 알림 | UserNotifications (로컬 알림) |
| 위젯 | WidgetKit (small / medium / 잠금화면 rectangular) |
| 차트 | Swift Charts |
| 테스트 | Swift Testing (Domain 레이어) |
| 프로젝트 | XcodeGen (`project.yml`) |

## 기능 (MVP 1 — 첫 출시 기준선)

**Core**
- 구독 등록·수정·삭제 — 프리셋(이름·카테고리·색상만, 로고·가격 없음) 또는 직접 입력. 필수 항목은 위, 선택 항목은 "더보기"
- 구독 목록 — 다음 결제일 가까운 순, D-day 배지(오늘·내일 오렌지 / 7일 이내 블루 / 그 외 회색), 왼쪽 스와이프 삭제(확인), 오른쪽 스와이프 일시중지
- 구독 상세 — 다음 결제일, 월 환산, 지금까지 낸 총액(추정), 알림 설정, 편집·일시중지·삭제
- 홈 — 이번 달 결제 예정액, 남은 결제, 월·연 환산, 다가오는 결제(7일, 최대 5건 + 더보기), 체험 중인 구독, 카테고리 차트

**Notify**
- 결제 알림 — 구독별 당일/1/3/7일 전/끔, 알림 시각 설정(기본 오전 9시)
- 무료체험 — 종료 3일 전·1일 전 알림, "체험 중" 배지, 종료 전까지 합계에서 제외
- 위젯 — 홈 소형(결제 예정액·남은 건수), 중형(+ 다가오는 결제 3건), 잠금화면(다음 결제 1건), 탭하면 해당 화면으로 이동(`subhelp://`)
- 온보딩 2장, 첫 구독 등록 직후 알림 권한 안내, 권한 거부 시 홈 배너
- 설정 — 기본 통화, 달러 환율(환산 금액에 ≈ 표시), 알림 기본값·시각, 권한 상태, 문의, 개인정보처리방침

## 시작하기

```bash
brew install xcodegen
cp Config/Local.xcconfig.example Config/Local.xcconfig   # 값 채우기 (아래 참고)
xcodegen generate
open Subhelp.xcodeproj
```

### 직접 채워야 하는 값 — `Config/Local.xcconfig`

비밀·개인 값은 코드에 하드코딩하지 않고 빌드 변수로 분리했다. `Config/Local.xcconfig`는 `.gitignore`에 들어 있어 커밋되지 않는다.

| 변수 | 설명 |
|---|---|
| `DEVELOPMENT_TEAM` | Apple Developer 팀 ID |
| `BUNDLE_ID_PREFIX` | 번들 ID 접두사 (예: `com.yourname`) → 앱 `<prefix>.subhelp`, 위젯 `<prefix>.subhelp.widget` |
| `APP_GROUP_ID` | App Group ID (예: `group.com.yourname.subhelp`). Developer 포털에서 생성 후 앱·위젯 App ID 둘 다에 연결 |
| `SUPPORT_EMAIL` | 설정 > 문의하기 (비우면 숨김) |
| `PRIVACY_POLICY_URL` | 설정 > 개인정보처리방침 (비우면 숨김). xcconfig에서 `//`는 주석이라 `https:/$()/example.com` 형태로 적는다 |

이 값들은 `Info.plist`(`AppGroupIdentifier` 등)와 entitlements에 주입되고, 코드에서는 `AppConfig`로만 읽는다.
App Group이 비어 있으면 앱은 앱 전용 저장소로 동작한다(위젯과 데이터 공유 안 됨).

## 구조

```
Subhelp/
├── App/            앱 진입점, AppRouter(탭·딥링크·권한 안내), 공유 ModelContainer, AppConfig
├── Domain/         결제일·금액 계산 (순수 로직, UI·SwiftData 의존 X) — 테스트 대상
├── Data/           Subscription (@Model), 프리셋·카테고리
├── Services/       NotificationService, SubscriptionSync (저장 → 알림 재예약 → 위젯 갱신)
├── Features/       Home / SubscriptionList / Detail / Editor / Settings / Onboarding
├── Shared/         공용 컴포넌트·포매터·설정·딥링크 (위젯과 공유)
└── Resources/      Assets, Info.plist, entitlements, PrivacyInfo, Localizable.xcstrings
SubhelpWidget/      위젯 익스텐션
SubhelpTests/       Domain 단위 테스트
Config/             빌드 변수 (xcconfig)
```

위젯 타깃은 `Domain/`, `Data/`, `Shared/`, `ModelContainer+Shared.swift`, `AppConfig.swift`를 함께 컴파일한다 (`project.yml`에 명시 — Target Membership 누락으로 인한 빌드 에러 방지).

## 기술적 의사결정

- **왜 서버 없이 시작했나** — 구독 데이터는 개인 기기 안에서 충분히 완결된다. 서버가 없으니 개인정보 라벨도 "데이터 수집 안 함"이고, 출시까지의 경로가 짧다. 동기화는 CloudKit으로 확장한다 (모든 모델 프로퍼티에 기본값을 둬서 미리 대비).
- **왜 MVVM이 아닌 `@Query` + Domain 분리인가** — SwiftData의 `@Query`는 뷰가 직접 데이터를 구독하도록 설계돼 있어, ViewModel로 감싸면 자동 갱신 이점을 잃는다. 그래서
  - 목록·조회 → 뷰에서 `@Query`
  - 계산 로직 → `Domain/`의 순수 struct (`BillingPlan` 값 타입으로 SwiftData와 분리) → 단위 테스트
  - 부수효과 → `Services/`
  - 편집 폼처럼 복잡한 화면 상태만 `@Observable` (`SubscriptionDraft`)
- **다음 결제일·월 환산은 저장하지 않고 계산** — 데이터 불일치 방지.
- **무료체험** — 체험 종료일 이전 결제일은 결제로 치지 않는다(종료일 당일부터 유료). 체험 중 구독은 월·연 환산에서도 제외.
- **금액은 Decimal** — Double 부동소수 오차 방지. 환율 입력(Double)도 문자열을 거쳐 Decimal로 변환.

## 트러블슈팅 기록

- **월말 결제일 밀림** — 1/31 시작 월결제를 "이전 결제일 + 1개월"로 반복하면 1/31 → 2/28 → 3/28로 밀린다. 항상 "최초 결제일 + n번째 주기"로 계산해서 해결. 시작일이 오래된 경우를 위해 경과 주기 수만큼 건너뛰고 계산한다.
- **알림 64개 한도** — 구독마다 다음 2회분만 예약하고, 앱 활성화·데이터 변경 시 전체 재예약. 한도를 넘으면 가까운 알림부터 남긴다.
- **위젯과 데이터 공유** — App Group 컨테이너에 SwiftData 저장소를 두고, 앱에서 변경 시 `save()` 후 `WidgetCenter.reloadAllTimelines()`. 환율 등 설정도 App Group `UserDefaults`에 저장.

## 테스트

```bash
xcodebuild test -project Subhelp.xcodeproj -scheme Subhelp \
  -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO
```

테스트 타깃은 앱을 호스트로 띄우지 않고 `Domain/` 소스를 직접 컴파일한다 (서명·App Group 없이 실행 가능). GitHub Actions(`.github/workflows/ci.yml`)에서 앱·위젯 빌드와 테스트를 자동 실행한다.

## 출시 전 체크리스트

- [ ] `Config/Local.xcconfig` 값 채우기, Developer 포털에서 App ID·App Group 생성
- [ ] 앱 아이콘 1024px (+ 다크/틴트 변형) → `Assets.xcassets/AppIcon`
- [ ] 개인정보처리방침 페이지 (Notion 공개 페이지 / GitHub Pages)
- [ ] App Store Connect: 앱 이름·부제·키워드, 6.9인치 스크린샷, 개인정보 라벨 "데이터 수집 안 함"
- [ ] 실기기에서 알림 수신·위젯 갱신 확인, TestFlight 크래시 로그 확인

## 로드맵 (MVP 이후)

1. iCloud 동기화 — `ModelConfiguration(cloudKitDatabase: .automatic)`
2. 인터랙티브 위젯 (App Intents)
3. 무료체험 종료 Live Activity
4. 실시간 환율 API + 캐싱
5. 서비스별 해지 링크 모음
6. (선택) 서버 — 프리셋 원격 관리, 가족 요금제 공유
