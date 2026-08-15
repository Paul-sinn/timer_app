# App Store 심사 답변 (Guideline 2.1 — Information Needed)

거절이 아니라 **정보 요청**이다. 코드 문제가 아니고, App Store Connect의
`App Review Information → Notes`가 비어 있어 심사자가 앱을 어떻게 써야 할지 몰라 되돌린 것.

아래 영문 블록을 **그대로 복사해 Notes에 붙여넣으면** 된다(심사자는 영어로 읽는다).
`⟨…⟩`로 표시한 곳만 직접 채운다. 이 문서는 다음 제출에도 재사용한다.

---

## 붙여넣을 영문 답변

```text
── 1. SCREEN RECORDING ──
A screen recording is attached, captured on a physical ⟨DEVICE⟩ running iOS ⟨VERSION⟩.

Please note: the app's core reward — an egg hatching into a creature — is earned by
completing a full 25-minute focus session. That commitment is the entire point of the
app: the reward exists precisely because the session is not trivial to finish.

So that the reviewer does not have to wait 25 minutes in real time, the middle of the
focus session in the recording is fast-forwarded (marked on screen). The session start,
the egg cracking through its stages, and the hatch itself are all shown at normal speed
and are uncut.

── 2. DEVICES AND OS VERSIONS TESTED ──
- iPhone ⟨MODEL⟩ — iOS ⟨VERSION⟩ (physical device, full manual testing)
- iPhone 17 Pro — iOS 26.5 (Simulator, automated unit test suite)

The app is iPhone-only, portrait orientation, and requires iOS 26.5 or later.

── 3. WHAT THE APP DOES, AND WHO IT IS FOR ──
Hatcho is a focus timer for people who struggle to stay off their phone while
studying or working.

Problem: ordinary countdown timers give you nothing for finishing, so it costs
nothing to quit early.

Solution: while the timer runs, an egg on screen visibly cracks in stages. If you
finish the session, the egg hatches into a pixel-art creature that you keep. Keep
completing sessions with that creature and it evolves through three forms. Quitting
early means no reward, which gives a small concrete reason to stay in the session.

Target audience: students and knowledge workers who want longer uninterrupted focus
blocks. No age-restricted content; the app is suitable for general audiences.

Core features:
- Focus timer with two modes: Normal (25 / 50 / 75 minutes) and Pomodoro
  (25 min focus / 5 min break / 15 min long break every 4 blocks)
- Egg hatching with rarity tiers (common / rare / legendary) determined by a
  probability table; longer sessions improve the odds
- Collection tab showing every creature hatched
- Progress tab with focus statistics and streaks
- Optional local notifications when a break or session ends
- Screen stays awake during a focus session

── 4. HOW TO SET UP AND ACCESS THE MAIN FEATURES ──
NO ACCOUNT IS REQUIRED. Every feature above works immediately after install with
no sign-up, no login, and no demo credentials. All data is stored locally on device.

To reach the core feature:
1. Launch the app and page through the 4 onboarding screens.
2. On the Home tab, choose "Normal" mode and a duration (25 min is the shortest).
3. Tap "Start". The egg cracks progressively as the session advances.
4. When the timer completes, the egg hatches and the creature is added to the
   Collection tab.

Optional sign-in (Sign in with Apple) is offered on the MyPage tab. Its ONLY purpose
is to back up and sync the collection across the user's own devices. It unlocks no
content. The reviewer can sign in with their own Apple ID; no demo account exists
because accounts hold nothing but the user's own focus history.

Account deletion: MyPage → "Delete account". This permanently deletes the account
and all associated server-side data (Guideline 5.1.1(v)).

── 5. EXTERNAL SERVICES USED ──
- Supabase (supabase.com) — Authentication and Postgres database. Used ONLY when a
  user chooses to sign in, to mirror their own focus history and collection for
  cross-device sync and backup. Signed-out users never contact this service.
- Sign in with Apple (Apple) — the only sign-in provider in this version.

No other third-party services. Specifically, the app contains NO advertising SDKs,
NO analytics SDKs, NO AI or machine-learning services, NO payment processors, and
NO user-generated content, messaging, or social features.

── 6. REGIONAL DIFFERENCES ──
None. The app ships in English only and behaves identically in every region. There
is no region-gated content, no region-specific pricing, and no geo-based logic.

── 7. REGULATED INDUSTRY / THIRD-PARTY MATERIAL ──
Not applicable. The app is not in a regulated industry and makes no health, medical,
financial, or educational-accreditation claims.

All artwork (eggs, creatures, backgrounds) is original work created for this app by
the developer. No licensed or third-party protected material is included.

── ADDITIONAL NOTES ──
- Permissions: the app requests only Notifications (local notifications for
  break/session end). It never requests location, contacts, camera, microphone,
  photos, or App Tracking Transparency, and collects no advertising identifiers.
- In-app purchases: none in version 1.0. The app is free with no paid tier,
  no subscriptions, and no locked content.
- Encryption: uses only standard HTTPS (ITSAppUsesNonExemptEncryption = NO).
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

⚠️ **녹화는 반드시 "이번에 올릴 새 빌드"로 찍는다.** build 2로 찍으면 부화 연출이 옛날 것
(PNG 7프레임)이라 새 바이너리(60fps 영상 + 화면 섬광)와 화면이 달라진다 — 같은 불일치 문제다.

| 순서 | 보여줄 것 | 왜 필요한가 |
|---|---|---|
| 1 | 홈 화면에서 **앱 아이콘 탭 → 실행** | Apple이 "must begin with launching the app"이라고 못박음 |
| 2 | 온보딩 4장 넘기기 | 첫 실행 경험 |
| 3 | **알림 권한 팝업 뜨고 허용** | "prompts requesting access" 항목 |
| 4 | Normal / 25분 선택 → Start | 핵심 진입 |
| 5 | 타이머 도는 중 알에 금 가는 것 | 핵심 메커니즘 |
| 6 | **부화 순간 (알 깨짐 → 캐릭터 등장)** | 앱의 존재 이유. 절대 빼면 안 됨 |
| 7 | Collection 탭 — 부화한 캐릭터 | 보상이 남는다는 증거 |
| 8 | Progress 탭 — 통계 | |
| 9 | MyPage → **Sign in with Apple 로그인** | "login flow" 항목 |
| 10 | MyPage → **Delete account → 삭제 완료** | "account deletion flow" 항목 — Apple이 특히 본다 |
| 11 | Settings — 알림/소리/진동/테마 | |

**6번 부화 장면 처리:** 25분을 실시간으로 다 찍을 수는 없다. 두 가지 방법:
- **권장**: 25분 세션을 실제로 돌리며 녹화 → 중간을 빨리감기(타임랩스)로 편집하고, 부화 순간은 **등속으로** 남긴다. 영상에 "fast-forwarded" 자막을 넣으면 심사자가 오해하지 않는다.
- 대안: 영상을 두 개로 나눠 제출(① 전체 UI 투어 ② 부화 순간만).

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

## 제출 체크리스트 (새 빌드를 같이 올리는 경우)

2.1 Information Needed는 **원래는 답변만 달면** 같은 빌드로 재심사된다.
다만 이번엔 그동안 수정한 것(부화 연출 교체, 동기화 잘림 버그 등)을 새 빌드로 올리기로 했으므로
**"새 빌드 업로드 + 답변"을 같이** 한다. 새 빌드를 올리면 심사는 처음부터 다시 돈다.

**빌드 올리기 전**

- [ ] `CURRENT_PROJECT_VERSION`을 **2 → 3**으로 올린다.
      같은 빌드 번호는 업로드 자체가 거부된다
- [ ] `MARKETING_VERSION`은 **`1.0` 그대로 둔다.**
      1.0이 승인된 적이 없으니 1.0.1로 갈 이유가 없다 — 이건 "1.0의 새 빌드"다
      (`NEXT_RELEASE.md`는 1.0이 통과했을 경우를 전제로 쓰여 있다)
- [ ] Archive → App Store Connect 업로드

**녹화**

- [ ] 올린 것과 같은 코드의 **Release 빌드**를 실기기에 설치 (Xcode 직접 설치 OK, TestFlight도 OK)
- [ ] 집중 시간 칩을 탭해 `10 sec (test)`가 **안 보이는지** 확인 (보이면 Debug — 중단)
- [ ] 위 11단계 순서로 화면 녹화 — **부화 순간 · 로그인 · 계정 삭제** 반드시 포함
- [ ] 25분 구간 타임랩스 편집 + 영상에 `fast-forwarded` 자막

**제출**

- [ ] 영문 답변의 `⟨…⟩` 채우기 — 기기 모델, iOS 버전
- [ ] 개인정보처리방침 URL · 지원 URL이 실제로 열리는지 확인
- [ ] **Resolution Center에 답변 + 영상 첨부**
      — 새 빌드만 올리면 Apple의 질문 7개는 그대로 남는다. 답변은 반드시 따로 달아야 한다
- [ ] 같은 내용을 `App Review Information → Notes`에도 붙여넣기
      (Apple이 "for future submissions"라고 요청 — 다음 제출부터 이 단계가 생략된다)

---

## 같이 확인해 둘 것

- **개인정보처리방침 URL** — App Store Connect에 필수. `docs/privacy-policy.md`가
  실제 접속 가능한 주소로 올라가 있는지 확인(GitHub Pages 등). ⟨URL: ⟩
- **지원 URL** — `docs/support.md` 동일. ⟨URL: ⟩
- **App Privacy(개인정보 수집) 설문** — 로그인 시 Supabase에 이메일·집중기록이
  저장되므로 "Identifiers / User Content"를 수집으로 신고해야 한다. 비로그인은 수집 없음.
- **스크린샷** — 로그인 화면이나 스플래시만 있으면 3.1.2/2.3.3로 반려된다.
  알이 부화하는 순간과 컬렉션 화면이 들어가야 한다.
