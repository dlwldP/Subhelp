# Subhelp — 구독 관리 iOS 앱

**흩어진 구독 결제를 한곳에 모아, 언제·얼마가 빠져나가는지 미리 알려주는 앱.**
기본은 계정 없이 기기 저장(SwiftData)으로 동작하고, 원하면 Apple 로그인으로 Supabase에 백업·동기화한다.

| 항목 | 결정 |
|---|---|
| 최소 타깃 | iOS 17+ |
| UI | SwiftUI |
| 저장소 | SwiftData (App Group 컨테이너 → 위젯과 공유) |
| 알림 | UserNotifications (로컬 알림) |
| 위젯 | WidgetKit (small / medium / 잠금화면 rectangular) |
| 차트 | Swift Charts |
| 테스트 | Swift Testing (Domain 레이어) |
| 서버 (선택) | Supabase — 프리셋 원격 관리, Apple 로그인, 구독 백업·동기화 (supabase-swift SDK) |
| 프로젝트 | XcodeGen (`project.yml`) |

## 기능

**Core**
- 구독 등록·수정·삭제 — 프리셋(이름·카테고리·색상만, 로고·가격 없음) 또는 직접 입력. 필수 항목은 위, 선택 항목은 "더보기"
- 구독 목록 — 결제일순·금액순(월 환산)·이름순 정렬, 카테고리 필터, D-day 배지(오늘·내일 오렌지 / 7일 이내 블루 / 그 외 회색), 왼쪽 스와이프 삭제(확인), 오른쪽 스와이프 일시중지
- 구독 상세 — 다음 결제일, 월 환산, 지금까지 낸 총액(추정), 알림 설정, 편집·일시중지·삭제
- 홈 — 이번 달 결제 예정액, 남은 결제, 월·연 환산, 다가오는 결제(7일, 최대 5건 + 더보기), 곧 갱신되는 연간 결제, 체험 중인 구독

**Notify**
- 결제 알림 — 구독별 당일/1/3/7일 전/끔, 알림 시각 설정(기본 오전 9시)
- 무료체험 — 종료 3일 전·1일 전 알림, "체험 중" 배지, 종료 전까지 합계에서 제외
- 위젯 — 홈 소형(결제 예정액·남은 건수), 중형(+ 다가오는 결제 3건), 잠금화면(다음 결제 1건), 탭하면 해당 화면으로 이동(`subhelp://`)
- 온보딩 2장, 첫 구독 등록 직후 알림 권한 안내, 권한 거부 시 홈 배너
- 설정 — 기본 통화, 달러 환율(환산 금액에 ≈ 표시), 알림 기본값·시각, 권한 상태, 문의, 개인정보처리방침

**Insight (MVP 2)**
- 통계 탭 — 카테고리별 월 환산 지출 도넛 차트 + 범례
- 결제 캘린더 — 월 이동, 날짜별 결제 점(구독 색), 날짜를 누르면 그날 결제 목록, 월 결제 건수·총액
- 비싼 구독 순위 — 월 환산 상위 5개 (체험 중 제외)
- 연간 결제 예고 — 30일 이내 연간 갱신을 홈에서 강조

**Server (Supabase, 선택)**
- 프리셋 원격 관리 — 로그인 없이 `presets` 테이블에서 받아 캐시, 실패하면 번들 기본값
- Apple 로그인(설정 > 계정·동기화) — 로그인하면 구독을 서버에 백업하고 여러 기기에서 동기화
- 로그아웃·계정 삭제 — 기기의 구독은 남고, 계정 삭제 시 서버 데이터는 모두 삭제
- `SUPABASE_URL`/`SUPABASE_ANON_KEY`가 비어 있으면 서버 기능이 숨겨지고 기기 저장만으로 동작

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
| `SUPABASE_URL` | Supabase > Project Settings > API > Project URL (`https:/$()/xxxx.supabase.co`) |
| `SUPABASE_ANON_KEY` | 같은 화면의 `anon` `public` 키. 앱에 들어가도 되는 공개 키(RLS로 보호). **`service_role` 키는 절대 넣지 않는다** |

- 이 값들은 `Info.plist`(`AppGroupIdentifier` 등)와 entitlements에 주입되고, 코드에서는 `AppConfig`로만 읽는다.
- App Group이 비어 있으면 앱은 앱 전용 저장소로 동작한다(위젯과 데이터 공유 안 됨).
- Supabase 값이 비어 있으면 로그인·동기화·원격 프리셋이 숨겨지고 기기 저장만으로 동작한다.
- 최근 만든 Supabase 프로젝트는 대시보드에서 `anon` 대신 **publishable key**(`sb_publishable_...`)로, 메뉴는 "API Keys"/"Data API"로 보일 수 있다. 같은 용도의 공개 키를 넣으면 된다.

### Supabase 설정

1. Supabase에서 프로젝트 생성
2. SQL Editor에 `supabase/migrations/0001_init.sql`을 붙여넣고 실행 — `presets`, `subscriptions` 테이블, RLS 정책, `delete_account()` 함수, 프리셋 초기 데이터
3. Authentication > Sign In / Providers > **Apple** 활성화, Client IDs에 앱 번들 ID(`<BUNDLE_ID_PREFIX>.subhelp`) 입력
   (앱 안의 네이티브 Apple 로그인만 쓰므로 Secret Key는 필요 없다)
4. Apple Developer > Identifiers > 앱 App ID에 **Sign in with Apple** 기능 체크
5. `Config/Local.xcconfig`에 `SUPABASE_URL`, `SUPABASE_ANON_KEY` 입력 후 `xcodegen generate`
6. **계정 삭제용 Edge Function 배포** (아래)

### 계정 삭제 Edge Function (`supabase/functions/delete-account`)

Apple 로그인 계정을 삭제할 때는 Apple 토큰도 철회해야 한다(App Store 계정 삭제 요건). 철회에는 Apple 개인 키(.p8)가 필요해서 앱이 아니라 이 함수에 둔다.

- 흐름: 설정 > 계정 삭제 → Apple로 한 번 더 확인(authorizationCode 획득) → 함수가 Apple 토큰 교환·철회 → Supabase 계정 삭제(구독은 cascade 삭제)
- Apple 철회가 실패해도 계정 삭제는 진행하고 응답의 `appleTokenRevoked`로 알린다 (함수 로그 확인)
- 함수가 배포되지 않았거나 호출에 실패하면 앱은 DB 함수 `delete_account()`로 계정만 삭제한다 (Apple 철회 생략)

배포:

1. Apple Developer > Keys > **+** → Sign in with Apple 체크, 앱 App ID 선택 → `.p8` 다운로드, Key ID 확인 (`.p8`은 한 번만 받을 수 있다)
2. Secrets 등록 — `supabase/functions/.env.example`을 `supabase/functions/.env`로 복사해 채운 뒤 (`.env`는 커밋되지 않음)
   ```bash
   supabase login
   supabase link --project-ref <프로젝트 ref>
   supabase secrets set --env-file supabase/functions/.env
   supabase functions deploy delete-account
   ```
   | Secret | 값 |
   |---|---|
   | `APPLE_TEAM_ID` | Apple Developer 팀 ID |
   | `APPLE_KEY_ID` | 1번 키의 Key ID |
   | `APPLE_PRIVATE_KEY` | `.p8` 파일 내용 전체 (한 줄로 넣을 때 줄바꿈은 `\n`) |
   | `APPLE_CLIENT_ID` | 앱 번들 ID (`<BUNDLE_ID_PREFIX>.subhelp`) |

   `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`는 Supabase가 함수에 자동으로 넣어준다.

### 동기화 방식

- 매 동기화마다 내 구독 전체를 받아 `SyncPlanner`(Domain, 단위 테스트) 규칙으로 병합 — 마지막 수정 우선(Last-Write-Wins), 삭제는 수정보다 우선
- 삭제는 서버 행을 바로 지우지 않고 `deleted_at`을 남겨(tombstone) 다른 기기에도 전파
- 시점: 로그인 직후, 앱 실행·복귀, 구독 변경 1.5초 후(연속 수정은 묶음)
- 수정 시각은 서버 정밀도(밀리초)에 맞춰 저장 — 맞추지 않으면 매번 "기기가 최신"으로 판단돼 업로드가 반복된다

## 구조

```
Subhelp/
├── App/            앱 진입점, AppRouter(탭·딥링크·권한 안내), 공유 ModelContainer, AppConfig
├── Domain/         결제일·금액 계산 (순수 로직, UI·SwiftData 의존 X) — 테스트 대상
├── Data/           Subscription (@Model), 프리셋·카테고리
├── Services/       NotificationService, SubscriptionSync (저장 → 알림 재예약 → 위젯 갱신 → 동기화), Supabase/
├── Features/       Home / SubscriptionList / Detail / Editor / Stats / Settings / Onboarding
├── Shared/         공용 컴포넌트·포매터·설정·딥링크 (위젯과 공유)
└── Resources/      Assets, Info.plist, entitlements, PrivacyInfo, Localizable.xcstrings
SubhelpWidget/      위젯 익스텐션
SubhelpTests/       Domain 단위 테스트
Config/             빌드 변수 (xcconfig)
supabase/           DB 스키마 (migrations), Edge Function (functions/delete-account)
```

위젯 타깃은 `Domain/`, `Data/`, `Shared/`, `ModelContainer+Shared.swift`, `AppConfig.swift`를 함께 컴파일한다 (`project.yml`에 명시 — Target Membership 누락으로 인한 빌드 에러 방지).

## 기술적 의사결정

- **왜 로컬 우선 + 선택형 서버인가** — 구독 데이터는 기기 안에서 충분히 완결된다. 그래서 로그인 없이 모든 기능이 동작하고, 서버(Supabase)는 기기 변경 대비 백업·다기기 동기화와 프리셋 원격 관리에만 쓴다. 서버 설정이 없으면 서버 코드는 아예 동작하지 않는다.
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

테스트 타깃은 앱을 호스트로 띄우지 않고 `Domain/` 소스를 직접 컴파일한다 (서명·App Group 없이 실행 가능). GitHub Actions(`.github/workflows/ci.yml`)에서 앱·위젯 빌드와 테스트, Edge Function 타입 체크(`deno check`·`lint`·`fmt`)를 자동 실행한다.

## 로드맵 (MVP 이후)

1. 인터랙티브 위젯 (App Intents)
2. 무료체험 종료 Live Activity
3. 실시간 환율 API + 캐싱
4. 서비스별 해지 링크 모음
5. 공유 구독(가족 요금제 N빵) — Supabase 위에 확장
