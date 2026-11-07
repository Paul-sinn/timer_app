# App Store 심사 답변 (Guideline 2.1 — Information Needed)

거절이 아니라 **정보 요청**이다. 코드 문제가 아니고, App Store Connect의
`App Review Information → Notes`가 비어 있어 심사자가 앱을 어떻게 써야 할지 몰라 되돌린 것.

아래 영문 블록을 **그대로 복사해 Notes에 붙여넣으면** 된다(심사자는 영어로 읽는다).
`⟨…⟩`로 표시한 곳만 직접 채운다. 이 문서는 다음 제출에도 재사용한다.

---

## 붙여넣을 영문 답변

```text
Hatcho — Response to Guideline 4 (Design, iPad) and Guideline 2.1 (Information Needed)
Build under review: 1.0 (9)

── 0. GUIDELINE 4 — IPAD LAYOUT FIX ──
Thank you for the September 2 review on iPad Air 11-inch (M3), build 1.0 (5).
Build 5 was iPhone-only, so it ran in iPad compatibility mode and some screens were
cut off at the bottom. Since then:
- Hatcho is now a universal app with native iPad layouts, supporting all
  orientations and Split View.
- Every screen adapts to the actual window size. Home switches to a two-column
  layout in landscape, and any content taller than the window now scrolls instead
  of being cropped.
- Verified on the iPad Air 11-inch Simulator and on a physical iPad.

── 1. SCREEN RECORDING ──
Video attached (hatcho_review_final.mp4).
Recorded on a physical iPhone. It shows app launch, onboarding, the notification
permission prompt, a focus session, hatching, the collection, Sign in with Apple, and
account deletion. To save time, the middle of the 25-min session is fast-forwarded
(labeled on screen); the session start and the hatch itself are uncut.
The video was recorded on build 5. Build 9 adds background themes (brush icon on
Home; the default is now a light "Butter" theme, so colors differ from the video),
a new app icon, and iPad layouts. The core flow shown is unchanged.

── 2. DEVICES & OS TESTED ──
- iPhone 17 — iOS 26.6 (physical device)
- iPhone 17 Pro — iOS 26.5 (Simulator)
- iPad (A16), 11-inch — iPadOS ⟨version⟩ (physical device)
Target: iPhone (portrait) and iPad (all orientations), iOS 26.5 or later.

── 3. WHAT THE APP DOES & TARGET AUDIENCE ──
Hatcho is a gamified focus timer for students and workers. Completing focus sessions
cracks and hatches virtual eggs into pixel-art creatures that evolve with more sessions.
Features: 25/50/75 min & Pomodoro timers, egg hatching/evolution, creature collection,
focus stats/streaks, and local notifications. General audience (no age-restricted
content).

── 4. HOW TO ACCESS MAIN FEATURES ──
NO ACCOUNT REQUIRED. All core features work locally out of the box.
1. Launch app and complete onboarding.
2. Home → "Normal" → 25 min → "Start".
3. Session runs, egg cracks progressively.
4. On completion, egg hatches and is added to the Collection tab.

Optional Sign in with Apple (MyPage) only backs up/syncs data across devices (unlocks
no extra features; reviewer may test with own Apple ID).
Account Deletion: MyPage → "Delete account" permanently deletes account and server data
(Guideline 5.1.1(v)).

── 5. EXTERNAL SERVICES ──
- Supabase: Auth & Postgres database used solely for optional cloud backup/sync when
  signed in. Signed-out users do not contact this service.
- Sign in with Apple: Only sign-in provider.
No ads, analytics, AI services, or third-party payment SDKs.
No user-generated content, messaging, or social features.

── 6. REGIONAL DIFFERENCES ──
None. Operates identically worldwide in English with no geo-restrictions.

── 7. REGULATED INDUSTRY / PROTECTED MATERIAL ──
N/A. No health, medical, or financial claims. All assets (eggs, creatures, UI) are
original artwork created by the developer.

── ADDITIONAL NOTES ──
- In-App Purchases: None in version 1.0. The app is free, with no paid tier, no
  subscriptions, and no locked content.
- Permissions: Local Notifications only (session/break alerts). No camera, mic, photos,
  tracking, or ad IDs.
- Encryption: Standard HTTPS only (ITSAppUsesNonExemptEncryption = NO).
```

---

## 화면 녹화 촬영 순서 (직접 해야 함)

### 어떤 빌드로 찍나 — **제출할 새 빌드의 Release 구성**

**실기기**로 찍는다. 시뮬레이터 녹화는 Apple이 반려한다.
아이폰 자체 화면 녹화(제어 센터)면 충분하다.

**Xcode에서 폰에 직접 꽂아 찍어도 된다. TestFlight 안 거쳐도 된다.**
단 **Run 구성이 `Release`여야 한다.** 빌드 설정으로 확인한 사실:

| 구성 | `SWIFT_ACTIVE_COMPILATION_CONDITIONS` | `#if DEBUG` |
|---|---|---|
| Debug | `DEBUG` | 켜짐 → `10 sec (test)` 노출 |
| Release | (미설정) | **꺼짐 → 없음** |

- 스킴의 `LaunchAction`(= Run)이 `Release`면 폰에 들어가는 빌드에 디버그 UI가 없다.
  (`ArchiveAction`은 원래부터 Release라 **배포용 아카이브는 늘 안전했다** — Run 구성은
  폰에 꽂아 테스트하는 빌드에만 영향을 준다.)
- **Debug 빌드로 찍으면 안 되는 이유**: 홈 상단 칩이 현재 선택한 집중 시간을 표시하는데
  (`HomeView.selectedDurationLabel`), Debug 빌드로 10초 세션을 돌리면 화면에
  **`10 sec (test)`가 그대로 찍힌다.** 이 컨트롤은 출시 바이너리에 없다
  (`durationOptions`가 `#if DEBUG`로 분기). 심사자가 영상에서 본 컨트롤을 실제 앱에서
  못 찾으면 **"영상과 바이너리가 다르다"는 새 반려 사유**가 생긴다. 칩을 화면에서 피할
  방법도 없다.

**녹화 직전 30초 자가 확인** — 앱에서 집중 시간 칩을 탭한다.

- `10 sec (test)`가 보인다 → **Debug다. 녹화 중단.** 스킴 Run 구성을 Release로 바꾼다
- `25 min / 50 min / 75 min`만 보인다 → Release다. 녹화해도 된다

⚠️ **녹화는 반드시 업로드한 `1.0 (5)`와 같은 코드로 찍는다.** 예전 build 2로 찍으면 부화 연출이
옛날 것(PNG 7프레임)이라 새 바이너리(60fps 영상 + 화면 섬광)와 화면이 달라진다 — 같은 불일치 문제다.
현재 HEAD(`e62e604`)가 곧 build 5의 코드이므로, 지금 Release로 빌드해 설치하면 된다.

| 순서 | 보여줄 것 | 왜 필요한가 |
|---|---|---|
| 1 | 홈 화면에서 **앱 아이콘 탭 → 실행** | Apple이 "must begin with launching the app"이라고 못박음 |
| 2 | 온보딩 4장 넘기기 | 첫 실행 경험 |
| 3 | **알림 권한 팝업 뜨고 허용** | "prompts requesting access" 항목 |
| 4 | Normal / 25분 선택 → Start | 핵심 진입 |
| 5 | 타이머 도는 중 알에 금 가는 것 | 핵심 메커니즘 |
| 6 | **부화 순간 (알 깨짐 → 캐릭터 등장)** | 앱의 존재 이유. 절대 빼면 안 됨 |
| 7 | Collection 탭 — 부화한 캐릭터 | 보상이 남는다는 증거 |
| 7-b | 캐릭터 탭 → **진화 3칸 스트립**(Just hatched / 실루엣 2칸) | 진화를 시연하지 않고 시스템만 보여준다. 진화 1단계는 25분 세션이 하나 더 필요하므로 **찍지 않는다** |
| 8 | Progress 탭 — 통계 | |
| 9 | MyPage → **Sign in with Apple 로그인** | "login flow" 항목. **순서는 자유** — 세션 시작 전에 먼저 로그인해도 된다 |
| 10 | Settings — 알림/소리/진동/테마 | 필수 항목은 아니다. 잠긴 테마가 없어(`AppTheme.isPro`가 전부 false) 화면에 "Coming soon"도 안 뜬다 |
| 11 | MyPage → **Delete account → 삭제 완료** | "account deletion flow" — **반드시 맨 마지막.** 먼저 지우면 뒤 화면이 비로그인으로 찍힌다 |

**11번 촬영 요령**
- 확인 알럿을 **1~2초 머문다.** 문구가 이미 `Local data on this device remains.`라고
  밝히고 있어, 삭제 후 컬렉션이 남아 있어도 심사자가 오해하지 않는다(설계대로다 —
  5.1.1(v)가 요구하는 건 서버 데이터 삭제이고, 로컬은 앱 삭제로 사라진다)
- 삭제 후 MyPage에 **2~3초 머문다.** `Sign in with Apple` 버튼이 다시 나타나는 것이
  계정이 실제로 사라졌다는 시각적 증거다

**6번 부화 장면 처리 — 빨리감기 편집**

25분을 실시간으로 다 보여줄 수는 없다. 세션 하나를 통으로 녹화한 뒤 **가운데만** 빨리감고
부화 순간은 등속으로 남긴다. `scripts/review_timelapse.sh`가 이걸 한 번에 한다.

```bash
./scripts/review_timelapse.sh <녹화파일> <빨리감기_시작> <빨리감기_끝> <배속> <출력파일>

# 예: 2분 지점부터 26분 지점까지 30배속
./scripts/review_timelapse.sh ~/Desktop/rec.mp4 00:02:00 00:26:00 30 hatcho_review.mp4
```

- 앞뒤(앱 실행~Start / 부화~계정삭제)는 **등속** 유지
- 가운데만 N배속 + 하단에 `FAST-FORWARDED xN` 자막 자동 삽입 (심사자 오해 방지)
- ⚠️ **부화 순간을 빨리감기 구간에 넣지 말 것.** 여유 있게 부화 30초 전에서 끊는다
- 25분을 30배속 → 50초. 최종 영상 5~6분

아이폰 "타임랩스"는 **촬영 모드**라 이미 찍은 영상엔 못 쓴다. 사진 앱에도 배속 조절이 없다.
맥 없이 하려면 CapCut(무료, 100배속까지). iMovie는 최대 2배속이라 부족하다.

---

## 안 해도 되는 것 (검토했고, 하지 않기로 한 것들)

### 25분 대기 문제 → 녹화 영상이 답이다. 코드 변경 불필요

출시 빌드의 집중 시간은 **25 / 50 / 75분**이다. 심사자가 부화를 직접 보려면 25분이 걸린다.

하지만 Apple은 "핵심 기능을 못 찾겠다"고 하지 않았다. **"정보를 달라"**고 했고,
그 1번 항목이 **화면 녹화**다. 즉 심사자가 앱에서 25분을 재현할 필요가 없도록
영상으로 보여주는 것이 Apple이 지정한 방법이다. 영상만 제대로 찍으면 해결된다.

### ❌ "5분" 같은 짧은 옵션 추가 — 제품을 망친다

5분마다 캐릭터를 얻을 수 있으면 반복 파밍이 가능해져 **부화 보상의 가치가 무너진다.**
이 앱의 핵심은 "끝까지 버텨야 보상이 있다"는 것이다. 심사 편의를 위해 그걸 깎으면 안 된다.

### ❌ 심사용 숨김 10초 모드(이스터에그) — 가이드라인 2.3.1 위반

> 2.3.1: Don't include any hidden or undocumented features in your app;
> your app's features should be clear to end users.

Apple에 알려준다 해도 **유저에게** 숨겨진 상태는 그대로다. 이 조항이 겨냥하는 게 정확히 그것이다.
얻는 것은 심사자 몇 분 절약인데, 잃을 수 있는 것은 앱 전체 반려다. 균형이 안 맞는다.

### ❌ 개발자 전용 로그인 계정 — 실익이 없다

이 앱의 계정은 **아무 콘텐츠도 잠그지 않는다.** 로그인 없이 전 기능이 동작하므로
데모 계정으로 열어줄 것 자체가 없다. 특정 계정만 다르게 동작시키려면 그 코드가
출시 빌드에 영구히 남고, 심사자는 보통 로그아웃 상태로 먼저 본다.

---

## 참고 — Google 로그인 (심사 지적사항 아님)

**Apple 반려 메시지에 Google 관련 내용은 없다.** 아래는 스토어 문구를 쓸 때 주의할 점이다.

`GoogleAuth.iosClientID`가 아직 `"REPLACE_WITH_IOS_CLIENT_ID..."` 플레이스홀더라
`isConfigured`가 false다. 즉 **Google 버튼은 화면에 안 나오고**, 지금 출시 빌드는
Apple 로그인 단독이다. 기능상 문제없다 — Apple 로그인만 제공하는 것은 정식 허용된다.

다만 앱 설명·스크린샷·심사 답변에 Google 로그인을 언급하면 **없는 기능을 광고**하는 게 되므로
반려 사유가 된다. 위 영문 답변은 Apple 로그인만 언급하도록 써 뒀다.
나중에 실제로 넣을 거면 클라이언트 ID와 URL scheme을 채운 뒤 새 빌드로 제출한다.

---

## 제출 체크리스트

2.1 Information Needed는 **원래는 답변만 달면** 같은 빌드로 재심사된다.
다만 이번엔 그동안 수정한 것(부화 연출 교체, 동기화 잘림 버그 등)을 새 빌드로 올렸으므로
**"새 빌드 + 답변"을 같이** 제출한다. 새 빌드를 올리면 심사는 처음부터 다시 돈다.

**빌드 업로드 — ✅ 완료 (2026-08-15)**

- [x] App Store Connect에 **`1.0 (5)`** 업로드 · 바이너리 검증됨
- [x] `MARKETING_VERSION`은 `1.0` 유지 (1.0이 승인된 적이 없으니 1.0.1로 갈 이유가 없다)
- 로컬 `CURRENT_PROJECT_VERSION`은 **3**이지만, Xcode가 업로드 시 자동으로 **5**로 올렸다
  (아카이브 Info.plist의 `uploadedBuildNumber = "5"`가 증거). 코드는 커밋 `e62e604`와 동일.
  **다음 업로드는 6 이상**이어야 한다

**녹화**

- [ ] 스킴 `Run` 구성이 **Release**인지 확인 (Debug면 `10 sec (test)`가 찍힌다)
- [ ] 계정 삭제 → 앱 삭제 → 재설치로 **완전 초기 상태** 만들기
      (앱만 지우면 키체인에 세션이 남아 재설치 직후 서버에서 데이터가 되돌아온다)
- [ ] 집중 시간 칩을 탭해 `10 sec (test)`가 **안 보이는지** 확인
- [ ] 위 11단계로 화면 녹화 — **부화 순간 · 로그인 · 계정 삭제** 반드시 포함
- [ ] `scripts/review_timelapse.sh`로 가운데 구간 빨리감기 + 자막

**제출**

- [ ] 영문 답변의 `⟨MODEL⟩` `⟨VERSION⟩` 채우기 (설정 → 일반 → 정보)
- [ ] 개인정보처리방침 URL · 지원 URL이 실제로 열리는지 확인
- [ ] **Resolution Center에 답변 + 영상 첨부**
      — 새 빌드만 올리면 Apple의 질문 7개는 그대로 남는다. 답변은 반드시 따로 달아야 한다
- [ ] 같은 내용을 `App Review Information → Notes`에도 붙여넣기
      (Apple이 "for future submissions"라고 요청 — 다음 제출부터 이 단계가 생략된다)
- [ ] 영상이 용량 때문에 안 붙으면 비공개 링크(Drive 등)를 답변에 넣는다

---

## 같이 확인해 둘 것

- **개인정보처리방침 URL** — App Store Connect에 필수. `docs/privacy-policy.md`가
  실제 접속 가능한 주소로 올라가 있는지 확인(GitHub Pages 등). ⟨URL: ⟩
- **지원 URL** — `docs/support.md` 동일. ⟨URL: ⟩
- **App Privacy(개인정보 수집) 설문** — 로그인 시 Supabase에 이메일·집중기록이
  저장되므로 "Identifiers / User Content"를 수집으로 신고해야 한다. 비로그인은 수집 없음.
- **스크린샷** — 로그인 화면이나 스플래시만 있으면 3.1.2/2.3.3로 반려된다.
  알이 부화하는 순간과 컬렉션 화면이 들어가야 한다.
