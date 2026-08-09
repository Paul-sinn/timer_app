# Hatcho — App Store Connect 제출 메타데이터

> 작성: 2026-08-01 · App Store Connect 제출 폼에 그대로 붙여넣는 값 모음.
> 스토어 페이지 카피(설명/키워드 등)는 `app-store-listing-en.md`와 동일 소스. 이 문서는 **제출 폼 전 항목**을 한 곳에 모은 것.
> `[FILL]` = 네가 직접 채워야 하는 값(전화번호·호스팅 URL 등).

---

## 2. 기본 메타데이터

### 설명 (Description · 최대 4,000자) — 영어
```
🥚 The focus timer that rewards you — Hatcho

Struggling to stay focused? Tired of plain timers that feel like a chore?

Hatcho turns your focus into a reward. Set a timer, dive into your study or work session, and every time you make it to the end, you hatch and collect an adorable monster. Focus becomes something you actually look forward to.

Focus → Reward → Focus again.
Every minute you concentrate becomes part of your own growing collection.


■ Made for you if you are
· A student building a consistent study habit
· A professional or freelancer who needs to get into deep work
· Anyone who finds plain timers boring and needs real motivation


■ Key Features
· Focus Timer — Set your session length and dive into deep work
· Pomodoro Mode — Focus/break cycles that hatch and evolve your monster
· Monster Collection — Finish a session and meet a brand-new monster
· Evolution — Keep focusing with the same friend and watch it grow
· Your Collection — Each monster greets you with its own lively personality
· Cross-device Sync — Sign in with Apple and keep your progress anywhere


■ Beat the three-day quitter
Don't rely on willpower alone. Let the monsters give you a reason to focus. Today's focus becomes tomorrow's collection.

Hatch your first monster now!
```

### 키워드 (Keywords · 최대 100자 · 쉼표구분 · 공백 없이)
```
focus,study,timer,pomodoro,monster,collect,habit,productivity,deep work,concentration,motivation
```
> 99자. App Name/Subtitle에 든 단어는 Apple이 자동 색인 → 중복 넣지 말 것.

### 지원 URL (Support URL) — **필수**
```
[FILL] https://<호스팅주소>/support
```
> 내용은 `docs/support.md`에 완비. **공개 URL로 호스팅 필요**(GitHub Pages 등). 미호스팅이면 제출 불가.

### 개인정보처리방침 URL (Privacy Policy URL) — **필수**
```
[FILL] https://<호스팅주소>/privacy
```
> 내용은 `docs/privacy-policy.md`에 완비. 마찬가지로 공개 호스팅 필요.

### 마케팅 URL (Marketing URL) — 선택
```
[FILL 또는 비움] https://<호스팅주소>
```

### 저작권 (Copyright)
```
2026 Paul Sin
```
> 형식 = `연도 소유자`. 법인이면 `2026 Hatcho Inc.` 식으로. (ASC가 © 자동 부착)

---

## 3. 빌드 (Build)

- 버전 **1.0** / 빌드 **1** (`MARKETING_VERSION=1.0`, `CURRENT_PROJECT_VERSION=1`).
- 업로드 방법: **Archive → 업로드**. 지금까지 만든 건 device용 `build`라 스토어엔 안 올라감 — 별도 아카이브 필요.
  ```bash
  cd ios
  xcodebuild archive -project Eggtimer.xcodeproj -scheme Eggtimer \
    -configuration Release -archivePath /tmp/Eggtimer.xcarchive \
    -destination 'generic/platform=iOS' -allowProvisioningUpdates
  # 이후 Xcode Organizer(Window > Organizer)에서 Distribute App > App Store Connect,
  # 또는 export 후 Transporter 앱으로 업로드.
  ```
- 업로드 후 ASC에서 처리(10~30분) 완료되면 이 빌드를 버전에 **선택**.

---

## 4. 앱 심사 정보 (Reviewer Info)

### 로그인 정보 (Sign-in)
- **로그인 필요? → 아니요 (체크 해제).** 앱 전 기능(타이머·부화·컬렉션·통계)이 **로그인 없이** 완전 동작. 테스트 계정 **불필요**.
- 로그인(Sign in with Apple)은 **선택** — 기기 간 클라우드 동기화용만. 심사관은 자기 Apple ID로 테스트 가능.

### 연락처 정보 (Contact Info)
| 항목 | 값 |
|---|---|
| 이름(First) | Paul |
| 성(Last) | Sin |
| 전화번호 | `[FILL]` |
| 이메일 | tlsrudgk13@gmail.com |

### 메모 (Review Notes) — 리젝 방지용, 붙여넣기
```
Hatcho is a focus timer with a monster-collection game layer. Notes for review:

- No account required. All features (timer, hatching, collection, stats) work fully offline without signing in. Sign in with Apple is OPTIONAL and only enables cross-device cloud sync. You can review the entire app without any account.

- Hatching is NOT a paid loot box. Monsters hatch by completing focus sessions (time spent focusing), never by payment or random purchase. This version has NO in-app purchases. No gambling or simulated gambling.

- Account & data deletion: the account section provides "Delete account," which permanently deletes the account and all cloud data (Guideline 5.1.1(v)). Local data is removed by deleting the app.

- Privacy: no third-party advertising, analytics, or tracking SDKs. Data (email, user ID, focus/collection history) is sent to our Supabase backend ONLY when the user chooses to sign in, for app functionality — not for tracking. This matches the bundled Privacy Manifest and the App Privacy answers.

- Content is 4+: dark-mode UI, no user-generated content, no social, no chat, no web browsing, no ads.
```

---

## 💡 선택 항목

### 프로모션 텍스트 (Promotional Text · 최대 170자 · 언제든 수정, 재심사 없음)
```
The more you focus, the more monsters you collect. Run a study or work timer, and every session you finish hatches a new monster. Make focus feel rewarding today.
```

### 부제 (Subtitle · 최대 30자) — 참고(별도 필드)
```
Focus timer that hatches pets
```
> 대안: `Focus. Hatch. Evolve.` (21) · `Focus more, collect monsters` (28)

### 이번 버전 새 기능 (What's New)
```
Welcome to Hatcho! Start a focus session, finish it, and collect your first monster. Build a focus habit that actually feels rewarding.
```

### 첨부 파일 (Attachment)
- 필수 아님. 앱이 오프라인·무계정으로 다 되므로 데모 영상 불필요. 필요 시 부화 흐름 짧은 클립 첨부 정도.

---

## ✅ 연령등급 (Age Rating) 답 요약 — 참고

- 앱 내 제어(부모제어·나이확인): **전부 아니요**
- 제공 기능(웹액세스·UGC·소셜·채팅·광고): **전부 아니요**
- 건강/웰빙 주제: **아니요** (생산성 앱, 웰빙 콘텐츠 없음)
- 폭력·성적·공포·도박: **전부 없음/None** (가챠는 무료 → 도박 아님)
- → 최종 **4+** 예상

---

## ⚠️ 제출 전 남은 블로커 (내 권한 밖)

| 항목 | 상태 |
|---|---|
| 지원·개인정보 URL 공개 호스팅 | ❌ 필요 (GitHub Pages 등) |
| ASC App Privacy 영양표 | ❌ 작성 — **`PrivacyInfo.xcprivacy` 선언(이메일·유저ID·이용기록, 비추적)과 일치** |
| 스크린샷 | ❌ 6.9"(iPhone Pro Max) 슬롯 필요 |
| 빌드 아카이브 업로드 | ❌ 위 3번 참고 |

> 코드/빌드 블로커는 0. 남은 건 호스팅 + ASC 폼 + 스크린샷 + 아카이브 업로드.

---

## 부록 A. FamilyControls 엔타이틀먼트 신청 (1.1 앱블로커용 — **오늘 신청**)

> 이건 **1.0 제출과 별개**. 앱블로커(방해앱 차단)는 1.1 예정이지만, Apple 승인 리드타임(며칠~몇 주)이 크리티컬패스라 **지금 신청만 걸어둔다**. 승인은 개발과 병렬로 굴러감.
>
> 신청 위치: developer.apple.com/contact/request → **Family Controls (Distribution)**.
> 폼의 "how your app uses the APIs" 칸에 아래 초안 붙여넣기.

### Use-case 초안 (영어 · 폼 붙여넣기용)
```
App: Hatcho — a focus timer that rewards the user with a collectible monster each time they complete a focus session.

How Hatcho uses Family Controls
Hatcho lets a user voluntarily block their OWN distracting apps during a focus session that they start themselves. This is opt-in self-control on the user's own device. Hatcho is NOT a parental-control, MDM, or monitoring product — it does not manage, observe, or report on anyone else's device or activity.

API usage
- FamilyActivityPicker: The user chooses which of their own apps/categories to keep out of reach during focus. The app never makes this selection for them.
- ManagedSettingsStore (shielding): When the user starts a focus session, the selected apps are shielded. The shield applies ONLY for the duration of the session the user chose, and is removed automatically when the session ends, is paused, or the user stops it. During Pomodoro breaks the shield is lifted.
- DeviceActivityMonitor (extension): Used only to align the shield with the focus-session window and to remove it when the schedule ends. It is not used to profile, log, or report the user's activity.

Privacy
The user's app selection is represented by opaque FamilyActivitySelection tokens that never leave the device. Hatcho collects no data about which apps are blocked, sends no device-activity data to any server, and contains no advertising or third-party tracking SDKs.

Why it is needed
Blocking distracting apps during a self-initiated focus session is a core motivation feature for our users (students and knowledge workers). No non-entitlement API can shield apps this way — Family Controls is the only supported mechanism.
```

### 승인 확률 체크 (우리 = 유리)
- ✅ 유저 본인의 self-control (부모통제·감시 아님)
- ✅ 유저가 자기 앱 직접 선택 · 세션 동안만 차단 · 자동 해제
- ✅ 선택 데이터 기기 밖 안 나감 · 광고·추적 없음
- ✅ 목적 명확(집중 세션 연동) · MDM·경쟁앱차단 아님 → 대표 반려사유 전부 해당 없음

### 신청 후 개발 체크리스트 (승인 나면)
- [ ] Xcode: `com.apple.developer.family-controls` capability 추가(승인 후 distribution)
- [ ] `DeviceActivityMonitor` 앱 익스텐션 타깃 신설
- [ ] `FamilyActivityPicker`로 차단앱 선택 UI(설정 or 세션 시작 플로우)
- [ ] 세션 start→shield, end/pause/break→unshield (SessionManager 연동)
- [ ] 크래시·백그라운드 복원 시 shield 상태 정합(안티치트 로직과 결합)
