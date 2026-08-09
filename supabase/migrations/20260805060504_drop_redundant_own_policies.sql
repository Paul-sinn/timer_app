-- [사후 복원] 이 파일도 리포를 거치지 않고 라이브 DB에 직접 적용됐던 마이그레이션을
-- supabase_migrations.schema_migrations 의 SQL 그대로 되살린 것이다.
-- 바로 앞 20260805060257 이 만든 own_* 정책을 되돌려, core_schema 의 *_own 정책만 남긴다.
-- (라이브 확인 결과 현재 두 테이블에는 focus_sessions_*_own / hatched_creatures_*_own 4개씩만 존재.)

-- 앞 마이그레이션이 원본 *_own 정책과 중복 생성한 own_* 제거(기능 동일, 정리 목적).
drop policy if exists own_select on public.focus_sessions;
drop policy if exists own_insert on public.focus_sessions;
drop policy if exists own_update on public.focus_sessions;
drop policy if exists own_delete on public.focus_sessions;
drop policy if exists own_select on public.hatched_creatures;
drop policy if exists own_insert on public.hatched_creatures;
drop policy if exists own_update on public.hatched_creatures;
drop policy if exists own_delete on public.hatched_creatures;
