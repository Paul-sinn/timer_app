# Phase 3 · Step 4 — SwiftData ↔ Supabase 동기화 서비스

**완료:** 2026-06-11

## 목표
로컬 도메인 값 타입을 Supabase 테이블 행으로 매핑하고, 본인 데이터를 push/pull 하는 동기화 서비스를 만든다. 매핑은 단위 테스트로 검증(네트워크/SwiftData 컨테이너 경로는 lessons에 따라 테스트 제외).

## 작업
- `Services/SyncModels.swift` (`nonisolated`, Codable + snake_case CodingKeys):
  - `FocusSessionRow` ↔ `FocusSessionResult`, `HatchedCreatureRow` ↔ `Creature`(미지원 종 nil), `ProfileRow`.
  - `id`는 로컬 SwiftData id와 동일 → upsert idempotent.
- `Services/SyncService.swift` (`nonisolated struct`):
  - `pushSessions/pushCreatures` — `upsert(rows, onConflict: "id")`.
  - `fetchSessions/fetchCreatures` — `select().eq("user_id", ...).order(...).execute().value`.
- `EggtimerTests/SyncModelsTests.swift` — round-trip(필드 보존)·snake_case 키·미지원 종 nil 검증.

## 검증
- `xcodebuild test ... -only-testing:EggtimerTests/SyncModelsTests` → **6/6 통과**, 빌드 성공.

## 보류
- 라이브 push/pull은 인증 세션 필요 → 공급자 설정 후 실기기/시뮬레이터에서 검증.
- 동기화 트리거(부화/세션 종료 시 자동 push, 로그인 시 pull→로컬 머지) 연결은 로그인 게이트와 함께.

## 다음
- (Phase 3 코드 스캐폴딩 일단락) 로그인 공급자 설정은 사용자 작업. 이후 UI 게이트 + 자동 동기화 연결.
