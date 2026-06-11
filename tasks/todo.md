# Phase 3 (step 1) — Supabase 클라우드 스키마 + RLS

## 목표
원격 Supabase에 로컬 SwiftData 모델을 미러링한 클라우드 스키마(profiles/focus_sessions/hatched_creatures) + RLS를 생성하고 마이그레이션으로 남긴다. iOS는 RLS 보호 하에 본인 행만 Supabase에 직접 read/write(결정). iOS SDK 연동/로그인/동기화는 다음 step.

## 작업
- [x] core 스키마 적용 (`create_core_schema`): 3 테이블 + 인덱스 + GRANT + RLS enable + 정책 12개
- [x] 트리거 적용 (`add_profile_trigger`): `handle_new_user`/`set_updated_at` + 트리거 + revoke
- [x] 검증: security advisor 경고 0, list_tables 컬럼/FK/check 일치, 마이그레이션 2건
- [x] 스모크: 정책 12 / 트리거 2 / definer 함수 public·anon·authenticated grant 0 확인
- [x] git 산출물: `supabase/migrations/*.sql` 2건, `docs/supabase/SCHEMA.md`
- [ ] 커밋

## 검증 결과
- `get_advisors(security)` → lints 0
- `get_advisors(performance)` → `unused_index` INFO 2건뿐 (0행·미쿼리라 정상, user_id 조회 시 사용됨)
- `list_migrations` → 20260611091144_create_core_schema, 20260611091157_add_profile_trigger
- `pg_policies` 12 / `pg_trigger` 2 / `handle_new_user` 외부 grant 0

## 설계 결정
- PK = 클라이언트 생성 UUID(로컬 id와 동일) → 동기화 idempotent upsert.
- 접근: iOS → Supabase 직접(RLS). FastAPI(ADR-004)는 AI 도입까지 보류.
- 레어도/종 메타는 클라 enum 단일 소스, DB 정규화 테이블 미생성(MVP).

## 다음 step (범위 밖)
- supabase-swift SDK, Apple/Google 로그인 UI, SwiftData↔Supabase 동기화 서비스
- Supabase Storage(캐릭터 에셋), 필요 시 FastAPI
