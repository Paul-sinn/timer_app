# Phase 3 · Step 1 — Supabase 스키마 + RLS

**완료:** 2026-06-11

## 목표
빈 원격 Supabase 프로젝트에 로컬 SwiftData 모델을 미러링한 클라우드 스키마 + RLS를 생성하고 마이그레이션으로 남긴다.

## 결정
- **접근 모델**: iOS → Supabase **직접** read/write, 행 접근은 RLS로 통제. FastAPI 경유(ADR-004)는 AI 도입까지 보류.
- **PK 전략**: `id` = 클라이언트 생성 UUID(로컬 SwiftData `id`와 동일) → 동기화 idempotent upsert.
- 레어도/종 메타는 클라 enum 단일 소스, DB 정규화 테이블 미생성(MVP).

## 산출물
- 원격: `profiles`, `focus_sessions`, `hatched_creatures` + 인덱스 2 + RLS 정책 12 + 트리거 2(`handle_new_user`, `set_updated_at`)
- 마이그레이션: `supabase/migrations/20260611091144_create_core_schema.sql`, `..091157_add_profile_trigger.sql`
- 문서: `docs/supabase/SCHEMA.md`

## 검증
- `get_advisors(security)` → lints 0
- `get_advisors(performance)` → `unused_index` INFO 2건(0행·미쿼리, 정상)
- `pg_policies` 12 / `pg_trigger` 2 / `handle_new_user` 외부 grant 0

## 다음
- Step 2: supabase-swift SDK 추가 + SupabaseClient 설정 서비스
