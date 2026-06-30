# Phase 4 step4 — 콜드런치 동료 복원 + 데이터 안전 점검

날짜: 2026-06-30 · 빌드 성공.

## 1. 콜드런치 동료 복원
- 문제: 동료(`hatchling`)가 `@State`라 앱 완전종료 후 재시작 시 `nil` → 키우던 캐릭터 대신 알이 뜸(컬렉션엔 남아있음).
- 해결: `@AppStorage("companionCreatureID")`에 동료 id 영속. `triggerHatch`에서 저장, `onAppear`의 `restoreCompanionIfNeeded()`로 컬렉션에서 같은 개체 복원. `takeNewEgg`에서 비움(복원이 '새 알' 의도 안 덮게). 진화 단계는 완료세션 수 파생이라 자동 복구.

## 2. 데이터 안전 점검(앱스토어 MVP 대비)
영속: SwiftData `HatchedCreatureRecord`/`FocusSessionRecord`(둘 다 `@Attribute(.unique) id: UUID` + 안정 필드, insert 후 `context.save()`). 로그인 시 Supabase 미러(추가 백업+기기간). 비로그인은 로컬만(iCloud 기기백업 포함, 앱 삭제 시 소실=정상).
- **현재 안전**: 이번 세션의 변경(파생 진화/도감 imageName 그룹핑/확률 2단계)은 **스키마 미변경** → 마이그레이션 위험 0.
- **향후 업데이트가 진짜 리스크**: `@Model` 필드 이름변경/삭제/타입변경 시 자동 마이그레이션 실패 → 데이터 소실/크래시.
- **정책 못박음**(CLAUDE.md CRITICAL): 필드 추가는 옵셔널/기본값만, 그 외 변경은 `VersionedSchema`+`SchemaMigrationPlan`+구버전 마이그레이션 테스트 후 릴리스. 동기화는 id 기준 idempotent 합집합만.
- 권장: 유저에게 로그인 유도(Supabase 백업으로 기기 분실/앱 삭제에도 복구). 비로그인 데이터 소실은 막을 수 없음.

## 미해결/사용자
- `try! ModelContainer`: v1은 이전 스키마 없어 마이그레이션 실패 불가. 향후 스키마 변경 시 위 정책 준수가 실질 방어책.
- 앱스토어 제출(아래 로드맵)은 대부분 사용자 작업.
