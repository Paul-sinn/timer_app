# Hatcho App Store Creative Assets Checklist

> **프로젝트 검증 (2026-10-12)** — 코드·에셋·Apple 공식 스펙과 대조해 체크했다.
> `[x]` = 확인됨 · `[ ]` = 제작/캡처 때 할 일 · **⚠️** = 원래 체크리스트와 실제 앱이 달라 고친 항목.

## 0. 제작 방향 확정

- [x] 기존 iPhone 스크린샷과 같은 Hatcho 브랜드 톤을 유지한다.
- [x] 첫 버전은 영상이 아닌 정적 이미지로 제작한다.
- [x] Universal 이미지 한 장을 억지로 공용하지 않고, 노출 목적에 맞춰 두 장을 별도로 제작한다.
  - Header: `3840 × 1646 px` (21:9) — Apple 스펙 일치 확인 (.png/.jpg)
  - Search Results: `3840 × 2560 px` (3:2) — Apple 스펙 **최대값** 일치 확인 (최소 1920 × 1280)
- [ ] App Store Connect의 Apple 공식 템플릿과 Preview에서 최종 크롭을 확인한다.

> 참고: `5244 × 2950 px`(16:9, **PNG만**) Universal 자산은 Header·Search Results 공용 가능. Hatcho는 별도 제작을 우선한다.

## 1. 각 이미지의 역할

### Product Page Header

> ⛔ **2026-11-06 반려(2.3.3)**: 아래 "브랜드·세계관 중심 / 앱 UI는 보조" 방향이 반려 사유였다. 헤더도 **실제 앱 화면이 주인공**이어야 한다. 다시 만들 땐 이 절을 따르지 말 것.

- [ ] 전달할 아이디어를 하나로 제한한다: **집중하면 알이 깨지고 귀여운 친구가 태어난다.**
- [ ] 첫 방문자가 앱의 분위기를 즉시 느끼도록 브랜드·세계관 중심으로 구성한다.
- [ ] 중앙에 빛나는 깨진 알 또는 부화 순간을 가장 큰 초점으로 둔다.
  - 실제 앱 연출과 일치: 부화 시 **앰버(#F2B44E)·크림(#FFFBF0) 방사형 섬광**이 알에서 터진다. 이 색을 쓰면 앱과 이어진다.
- [ ] 대표 캐릭터는 3–5종만 사용하고 화면을 도감처럼 빽빽하게 채우지 않는다.
- [ ] 추천 카피는 한 줄만 사용한다: **“Focus. Crack. Ta-da!”**
- [ ] 앱 UI를 넣더라도 보조 요소로만 사용한다.

### Search Results

- [ ] 작은 크기에서도 앱의 용도를 바로 이해할 수 있어야 한다.
- [x] 실제 `25:00` 집중 타이머 UI와 부화 보상을 함께 보여준다.
  - 확인: 기본 집중 시간 25분, 표시 형식 `25:00` (mm:ss). 선택지는 25/50/75분.
- [ ] 추천 카피: **“Focus Timer. Hatch Cute Pets.”**
- [ ] 타이머 → 알 → 캐릭터의 관계가 한눈에 읽히도록 구성한다.
- [ ] 캐릭터 수와 장식을 줄이고, 앱 UI와 핵심 보상을 크게 보여준다.

## 2. 기존 Hatcho 브랜드 유지

- [x] 앱 이름은 **Hatcho**로 통일하고 Hatchly를 사용하지 않는다.
  - 확인: 홈 화면/스토어 표시명 = `Hatcho`. (`hatchly`는 번들 ID에만 있고 유저에게 안 보임 — 이미지에 쓰지 말 것)
- [x] **팔레트 — 바깥은 파스텔, 앱 화면은 다크.** 기존 스크린샷 6장(`Hatcho_AppStore_Pastel_6.5in_1242x2688/`)에서 실측:
  - 슬라이드 배경(장마다 1색): 버터 옐로 `#FFE6A7` · 핑크 `#FFD8D2` · 라벤더 `#DDD7FF` · 민트 `#CFEBD8` · 스카이 `#CDE8F5` · 피치 `#FFDDBD`. 바깥 여백은 오프화이트.
    → 원래 목록(노랑·복숭아·라벤더·연파랑)에 **핑크·민트도 포함**. Header/Search는 이 중에서 골라 쓴다(버터 옐로 = 1번 장 "Focus. Crack. Ta-da!"와 같은 색이라 Header에 자연스럽다).
  - **앱 화면 안은 다크 고정 그대로**: 배경 `#171310`, 카드 `#221B16`, 강조 앰버 `#E8A03C`, 텍스트 크림 `#F5EDE0`, 전설 골드 `#F4B860`, 레어 블루 `#7FA9E8`. 앱 캡처 색을 파스텔로 바꾸지 말 것.
- [x] **타이포**: 헤드라인 = 굵은 둥근 서체(진한 브라운) + **배경과 같은 계열의 진한 색 손그림 밑줄**, 서브카피 = 작은 회갈색 한 줄. (앱 UI 글꼴은 SF Pro Rounded — 앱 화면 속 글자는 다시 그리지 말 것)
- [x] **장식 요소**(기존 6장 공통): 상단 `HATCHO` 알약 배지 + 우측 `n/6` 페이지 표시 · 다크 폰 화면에 **배경색 계열 테두리** + 상단 **와시테이프** 한 조각 · 배경과 톤온톤인 연한 손그림 낙서(알·병아리·하트·별·물결).
  - Header/Search에선 `n/6` 페이지 표시는 빼는 게 맞다(스크린샷 연작 표식이라).
- [ ] 기존 스크린샷, 앱 아이콘과 색상·폰트·메시지·톤이 한 세트처럼 보이게 한다.
- [ ] 너무 진지하거나 일반적인 생산성 앱 광고처럼 만들지 않는다.

## 3. 제작 전에 준비할 원본 자산

- [x] 최신 앱 아이콘 원본 → `ios/Eggtimer/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`
- [ ] ⚠️ Hatcho 워드마크 또는 텍스트 로고 → **레포에 없음.** 새로 만들거나 텍스트로 대체.
- [x] 깨지기 전 알 / 금이 간 알 / 부화 직후 알 이미지 → `images/`
  - 깨지기 전: `fullegg.png`
  - 금 간 단계: `firstcrack_egg.png` → `secondcrack_egg.png` → `thirdcrack_egg.png` → `fourthcrack_egg.png` → `abouttocrack_egg.png`
  - 부화 이펙트: `borneffect.png`
- [x] 대표 캐릭터 원본 스프라이트 → `images/final-character/{폴더}/{폴더}_stage{1-3}_{idle|action}.png`
  - Red Hen → `chicken/` (`Red Hen` = 앱 표기 확인)
  - Black Cat → `blackcat/`
  - Golden Chick → `goldchick/`
  - White Tiger → `white_tiger/`
  - Phoenix → `phoenix/`
  - 원본은 941 × 1672, **배경 불투명** → 배경 제거 필요. 원본 파일 자체는 수정 금지(복사해서 작업).
  - 참고: White Tiger·Phoenix는 **전설 등급(각 1%)**. 등장시켜도 되지만 "누구나 바로 얻는다"는 인상의 카피는 피할 것.
- [x] 최신 Home 타이머 화면 캡처(`25:00`, **Normal / Pomodoro** 토글, Start)
  - 확인: 영어 UI 표기는 `Normal`(문자열 카탈로그). 기존 스크린샷과 일치.
- [ ] 최신 Collection 화면 캡처
- [ ] 기존 App Store 스크린샷의 배경색·낙서·테이프 요소
- [x] 모든 UI와 캐릭터가 현재 출시 앱에 실제로 존재하는지 확인 → 위 5종 이름·이미지 모두 존재.

### ⚠️ 앱 화면 캡처 규칙 (새로 추가)
- [ ] **Release 빌드에서 캡처**(TestFlight 설치본). Debug 빌드엔 `10 sec (test)` 선택지와 마이페이지 `Developer (DEBUG)` 섹션이 보인다.
- [ ] **기기 언어 English**로 캡처. 한국어면 `25분` 등 한국어로 나온다.
- [ ] 앱엔 효과음이 없다(부화는 섬광 + 진동). 소리를 암시하는 표현(♪, 스피커 아이콘) 금지.

## 4. 픽셀아트 품질

> ⚠️ **원본이 "진짜 픽셀 격자" 아트가 아니다.** 측정 결과 941 × 1672 원본은 픽셀 블록이 일정하지 않은 고해상도 픽셀 스타일 렌더(같은 색 연속 길이 대부분 1px)라서, "nearest-neighbor로 축소"하면 오히려 들쭉날쭉해진다. 규칙을 아래처럼 바꾼다.

- [ ] 원본보다 **크게 확대하지 않는다**(최대 100%). 헤더에서도 캐릭터 높이는 원본 1672px 안쪽이면 충분.
- [ ] **축소**할 땐 고품질 리샘플링(Lanczos/Area)을 쓴다. nearest-neighbor 축소 금지.
- [ ] 정수 배율이 필요할 땐 1/2(50%)처럼 딱 떨어지는 비율을 우선한다.
- [ ] AI 업스케일·샤픈·자동 보정으로 캐릭터 모양을 바꾸지 않는다.
- [ ] 픽셀 가장자리가 흐려지거나 자동 보정되지 않았는지 100% 확대해서 확인한다.
- [ ] 텍스트와 배경 그래픽은 선명하게 유지하되 캐릭터 픽셀을 임의로 부드럽게 만들지 않는다.

## 5. 레이아웃과 안전 영역

- [ ] 가장 중요한 캐릭터·알·카피는 화면 중앙 안전 영역에 둔다.
- [ ] 좌우/상하 끝부분에는 잘려도 되는 배경과 낙서만 배치한다.
- [ ] Header는 매우 넓으므로 세로로 긴 휴대폰 화면을 주인공으로 만들지 않는다.
- [ ] Search Results는 작은 화면에서 보이므로 작은 설명문과 작은 캐릭터 군집을 피한다.
- [ ] 카피는 한 자산당 한 문구, 최대 두 줄로 제한한다.
- [ ] App Store Connect Preview에서 iPhone과 iPad 크롭을 모두 확인한다.
  - 확인: 앱이 1.0 (3)부터 **iPad 정식 지원**(유니버설). iPad 스토어 페이지에도 노출되니 iPad 크롭 확인은 필수.

## 6. Apple 정책·정확성

- [x] 앱의 실제 기능과 실제 콘텐츠만 표현한다. (타이머·부화·도감·진화 3단계 모두 실제 기능)
- [ ] 가격, 할인, 웹사이트 URL, 저작권 기호를 넣지 않는다.
- [ ] 다른 플랫폼·마켓 로고나 이름을 넣지 않는다.
- [ ] Editor’s Choice, App of the Day, 수상 경력 등 확인 불가능한 문구를 넣지 않는다.
- [x] 모든 연령에 적합한 4+ 수준의 이미지를 사용한다. (연령등급 4+ — `appstore/app-store-submission.md`)
- [ ] 영어 카피가 들어간 자산은 영어 로컬라이제이션에 먼저 등록한다.

## 7. 파일 출력

- [ ] Header: `Hatcho_Header_EN_3840x1646.png`
- [ ] Search Results: `Hatcho_Search_EN_3840x2560.png`
- [ ] 최종 파일에 알파 채널과 투명 영역이 없어야 한다. (Apple 스펙 명시 — 배경 제거한 캐릭터를 얹은 뒤 **불투명으로 flatten** 필수)
- [ ] 픽셀 규격과 화면 비율을 다시 확인한다.
- [ ] PNG를 다시 열어 색상·텍스트·픽셀 선명도를 확인한다.

## 8. 최종 육안 검사

- [ ] 이미지를 25% 이하로 축소해도 카피와 핵심 장면이 읽힌다.
- [ ] 3초 안에 “집중 타이머 + 부화 + 수집”이 이해된다.
- [ ] Header와 Search Results가 서로 복붙처럼 보이지 않고 각 역할이 분명하다.
- [ ] 기존 6장의 App Store 스크린샷과 함께 봤을 때 하나의 캠페인처럼 이어진다.
- [ ] 앱 아이콘과 이름 주변에 시각적 충돌이 없는지 Preview에서 확인한다.
- [ ] 오탈자, Hatchly 표기, 오래된 UI가 없는지 마지막으로 확인한다.

## 이번 제작의 기본 콘셉트

| 위치 | 핵심 장면 | 카피 | 목표 |
|---|---|---|---|
| Header | 빛나는 알이 깨지며 대표 캐릭터들이 등장 | Focus. Crack. Ta-da! | Hatcho의 세계관과 감정적 매력 전달 |
| Search Results | 실제 25:00 타이머 UI + 알 + 부화 캐릭터 | Focus Timer. Hatch Cute Pets. | 기능과 보상을 즉시 이해시키고 탭 유도 |

## Apple 공식 참고 자료

- [Creative assets specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/creative-assets-specifications)
- [App Store asset best practices and resources](https://developer.apple.com/app-store/asset-best-practices/)
- [Manage your App Store assets](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-your-app-store-assets/)
