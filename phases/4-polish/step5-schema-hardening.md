# Phase 4 step5 — 출시 전 스키마 보강(파괴적 변경 방지) + 진화 귀속 정확화

날짜: 2026-06-30 · 빌드 성공 · EggtimerTests 전건 통과 · Supabase 마이그레이션 적용·검증.

## 배경
"필드는 나중에 바꾸면 안 된다(데이터 소실)" → 출시 전에 **핵심 필드를 미리 박아** 향후 파괴적 마이그레이션을 피한다.
원칙: 필드 추가는 옵셔널/기본값만(lightweight 안전), 미래 churn은 jsonb로 흡수.

## Supabase 마이그레이션 (적용 완료, RLS 유지, advisor 깨끗)
`supabase/migrations/20260630120000_add_companion_mode_premium.sql` — 모두 nullable/default(파괴 없음):
- `focus_sessions.companion_id uuid` + `mode text` (+ companion 인덱스)
- `hatched_creatures.updated_at timestamptz`
- `profiles.settings jsonb default '{}'` + `is_premium boolean default false`
- 검증: list_tables로 컬럼 확인, 기존 데이터(focus 27행/creatures 6행) 보존, security advisor 무관 경고 1건(OAuth만 써서 해당 없음).

## 배선(active) — companion_id + mode
- `FocusSessionResult`/`FocusSessionRecord`(opt)/`FocusSessionRow`(snake) 에 `companionID: UUID?` + `mode: TimerMode?/String?` 추가.
- `SessionManager.companionID`(HomeView가 동료 변화 시 주입) → `buildResult`에 귀속 + `mode: s.mode`.
- **진화 누수 수정**: `FocusHistoryStore.completedSessions(since:)` → `completedSessions(forCompanion id:)`. 이제 "그 캐릭터와 완료한 세션"만 카운트 → 다른 동료로 집중해도 컬렉션 개체가 멋대로 진화하지 않음.
- HomeView: 부화/복원/새 알 받기 시 `session.companionID` 갱신. companionStage·RootView 클로저를 forCompanion으로.

## 미래용(컬럼만 박음, Swift 미배선 — 나중에 옵셔널 추가로 안전)
- `hatched_creatures.updated_at`: 기기간 동기화 충돌 해결.
- `profiles.settings(jsonb)`: 설정 동기화(미래 키 추가 시 컬럼 churn 없음).
- `profiles.is_premium`: 유료 플랜(30분 타이머·리롤) 게이트. 게이트는 StoreKit + 이 플래그.

## 주의
- 기존(이 변경 이전) 세션 행은 companion_id=null → 과거 파생 진화는 초기화. 출시 전이라 실유저 영향 없음.
- 동기화는 companion_id/mode 컬럼이 원격에 있어야 함(이미 적용). DTO가 보내도 안전.
