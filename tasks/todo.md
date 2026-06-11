# Phase 2-1 — 집중 세션 코어

## 목표
홈 화면이 실제로 동작: 실제 카운트다운 → 시간 기반 알 성장 → 목표 도달 시 확률 부화 → 컬렉션 반영. + 화면 꺼짐 방지.

## 작업
- [x] `FocusSessionState.swift` — SessionPhase + ActiveSession(타임스탬프 계산, 캡)
- [x] `ScreenAwake.swift` — 세션 중 idleTimer off, @AppStorage 설정 연동
- [x] `SessionManager.swift` — 상태머신/틱/재계산/경량 복구(UserDefaults)
- [x] `HomeView` — 집중시간 메뉴 + 단계별 컨트롤 + 완료 시 자동 부화 + scenePhase 연동
- [x] `HomeViewModel` 제거, RootView/ReviewGallery/프리뷰 갱신
- [x] MyPage — "화면 꺼짐 방지" 토글(@AppStorage)
- [x] 빌드 성공
- [x] `SessionManagerTests` — 주입 시계로 시작/일시정지/재개/완료/복구/단계 검증
- [x] 테스트 통과 (16/16) — `plannedSeconds` didSet 무한재귀(SIGSEGV) 버그 수정 후
- [ ] 시뮬레이터 육안 검증(idle/start/완료 부화)
- [ ] 커밋

## 디버깅 기록
- 증상: 시뮬레이터가 "Eggtimer 종료됨" 반복 + 테스트가 0.000초 동반 실패.
- 원인: `var plannedSeconds { didSet { ... plannedSeconds = oldValue } }` 자기대입 → 무한재귀 → 스택오버플로 SIGSEGV. 호스트 앱(테스트 러너) 크래시가 병렬 테스트까지 전부 죽임.
- 해결: 백킹 스토어(`_plannedSeconds`) + computed 세터(idle일 때만 반영).

## 스코핑
- 영속화는 활성 세션 1건만 UserDefaults 경량 복구. 전체 SwiftData 이력은 2-2.
- 검수용 DEBUG 10초 세션 옵션 제공.

## 메모
- 테스트 러너가 EggtimerUITests의 swiftStdLibTool(CopySwiftLibs) 단계에서 간헐적 행 → 시뮬레이터 재부팅 후 재시도.
