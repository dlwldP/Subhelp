# Subhelp — 구독 관리 iOS 앱

구독 결제일 알림과 지출 관리를 위한 iOS 앱. **서버 없이 로컬 우선(SwiftData)** 으로 만들고, 동기화·서버는 MVP 이후에 붙인다.

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

## 기능 (MVP)

- 구독 추가 / 수정 / 삭제 — 이름, 금액, 통화(KRW/USD), 주기(주/월/년 + 간격), 최초 결제일, 카테고리, 색상, 메모
- 구독 목록 — 다음 결제일 가까운 순, D-day, 스와이프 삭제·일시중지, 활성/비활성 세그먼트
- 홈 — 이번 달 결제 예정 금액, 남은 결제, 월 환산 평균, 연 환산, 7일 이내 결제, 카테고리 도넛 차트
- 결제일 알림 — 구독별 당일/1일/3일/7일 전 (오전 9시), 무료체험 종료 하루 전 알림
- 홈 화면·잠금화면 위젯
- 프리셋 (이름·카테고리만, 로고·가격 없음)

## 시작하기

```bash
brew install xcodegen
cp Config/Local.xcconfig.example Config/Local.xcconfig   # 값 채우기 (아래 참고)
xcodegen generate
open SubTracker.xcodeproj
```

### 직접 채워야 하는 값 — `Config/Local.xcconfig`

비밀·개인 값은 코드에 하드코딩하지 않고 빌드 변수로 분리했다. `Config/Local.xcconfig`는 `.gitignore`에 들어 있어 커밋되지 않는다.

| 변수 | 설명 |
|---|---|
| `DEVELOPMENT_TEAM` | Apple Developer 팀 ID |
| `BUNDLE_ID_PREFIX` | 번들 ID 접두사 (예: `com.yourname`) → 앱 `<prefix>.subtracker`, 위젯 `<prefix>.subtracker.widget` |
| `APP_GROUP_ID` | App Group ID (예: `group.com.yourname.subtracker`). Developer 포털에서 생성 후 앱·위젯 App ID 둘 다에 연결 |
| `SUPPORT_EMAIL` | 설정 > 문의하기 (비우면 숨김) |
| `PRIVACY_POLICY_URL` | 설정 > 개인정보처리방침 (비우면 숨김). xcconfig에서 `//`는 주석이라 `https:/$()/example.com` 형태로 적는다 |

이 값들은 `Info.plist`(`AppGroupIdentifier` 등)와 entitlements에 주입되고, 코드에서는 `AppConfig`로만 읽는다.
App Group이 비어 있으면 앱은 앱 전용 저장소로 동작한다(위젯과 데이터 공유 안 됨).

## 구조

```
SubTracker/
├── App/            앱 진입점, 공유 ModelContainer, AppConfig
├── Domain/         순수 로직 (UI·SwiftData 의존 X) — 테스트 대상
├── Data/           Subscription (@Model)
├── Services/       NotificationService, SubscriptionSync (저장 → 알림 재예약 → 위젯 갱신)
├── Features/       Dashboard / SubscriptionList / SubscriptionEditor / Settings
├── Shared/         공용 컴포넌트·확장·설정 (위젯과 공유)
└── Resources/      Assets, Info.plist, entitlements, PrivacyInfo
SubscriptionWidget/ 위젯 익스텐션
SubTrackerTests/    Domain 단위 테스트
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
- **금액은 Decimal** — Double 부동소수 오차 방지. 환율 입력(Double)도 문자열을 거쳐 Decimal로 변환.

## 트러블슈팅 기록

- **월말 결제일 밀림** — 1/31 시작 월결제를 "이전 결제일 + 1개월"로 반복하면 1/31 → 2/28 → 3/28로 밀린다. 항상 "최초 결제일 + n번째 주기"로 계산해서 해결. 시작일이 오래된 경우를 위해 경과 주기 수만큼 건너뛰고 계산한다.
- **알림 64개 한도** — 구독마다 다음 2회분만 예약하고, 앱 활성화·데이터 변경 시 전체 재예약. 한도를 넘으면 가까운 알림부터 남긴다.
- **위젯과 데이터 공유** — App Group 컨테이너에 SwiftData 저장소를 두고, 앱에서 변경 시 `save()` 후 `WidgetCenter.reloadAllTimelines()`. 환율 등 설정도 App Group `UserDefaults`에 저장.

## 테스트

```bash
xcodebuild test -project SubTracker.xcodeproj -scheme SubTracker \
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
