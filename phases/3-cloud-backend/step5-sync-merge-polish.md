# Phase 3 · Step 5 — 동기화 머지 로직 + 마감 (인증 대기 중 진행)

**완료:** 2026-06-11 · 사용자 Apple 개발자 등록 대기 중, 인증에 안 막히는 항목 진행.

## 작업
- **동기화 머지 정책** `Services/SyncMerge.swift`(순수): `diff(local:remote:)` → id 기준 양방향 합집합(원격에만 있는 것=로컬 insert, 로컬에만 있는 것=push). 세션·부화는 append-only라 충돌 병합 불필요. 로그인 붙으면 push/pull 래핑에 사용.
  - 테스트 `SyncMergeTests`(empty/단방향/겹침/동일/Creature) 통과.
- **앱 표시 이름** = `Studymon` (`INFOPLIST_KEY_CFBundleDisplayName`, 앱 타겟 Debug/Release). 내부 타겟명/번들 ID는 별개.
- **컬렉션 상세 성격 대사**: `CreatureDetailSheet`가 개체 성격(`Creature.personality`)의 등장 대사 한 줄을 인용으로 표시. `DialogueCatalog.greetingLines(for:)` 헬퍼 추가. (dialoguesystem.md "생명체는 성격별로 말한다" 마감)

## 검증
- 빌드 + `SyncMergeTests`/`DialogueCatalogTests` **TEST SUCCEEDED**.
- 앱 데이터 흐름(부화/세션 기록)은 건드리지 않음 → 기존 동작 무해.

## 보류(사용자 인증 후)
- push/pull 실제 연결(currentUserID 있을 때만) + 로그인 시 pull→`SyncMerge.diff`→로컬 insert.
- 로그인 UI(Apple/Google 버튼) + RootView 게이트 + GoogleSignIn-iOS SDK 추가.
