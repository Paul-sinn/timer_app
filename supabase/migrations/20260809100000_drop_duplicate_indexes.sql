-- 중복 인덱스 정리. Supabase performance advisor duplicate_index WARN 2건 해소.
--
-- 원인: 20260611091144_create_core_schema.sql 이 이미 만든 인덱스를
--       20260805060257_create_sync_tables_... 이 다른 이름으로 한 번 더 만들었다
--       (`create index if not exists` 는 "정의"가 아니라 "이름"으로만 존재 여부를 판단하므로 중복을 막지 못함).
--
-- 남기는 쪽: core_schema 원본 이름 (*_user_started_idx, *_user_hatched_idx)
--   - 리포에서 가장 오래된 정본(定本) 마이그레이션이 소유한 이름이라, 로컬 `supabase db reset` 으로
--     처음부터 재생성해도 항상 만들어진다. 반대로 idx_* 는 사후 복원 파일에만 존재.
--   - 컬럼/정렬/방식이 완전히 동일해 어느 쪽을 남겨도 플래너 동작은 같다. 이름의 출처가 판단 기준.
--
-- 드랍하는 쪽: 나중에 생긴 idx_* 2개.
--   - 라이브 확인: 둘 다 비유니크 · 비PK이며 pg_constraint 에 연결된 제약 뒷받침 인덱스가 아니다(conindid 매칭 0건).
--     따라서 드랍해도 PK/unique/FK 제약은 영향 없음.
--
-- `concurrently` 는 트랜잭션 블록 안에서 실행 불가 → 마이그레이션에서는 쓰지 않는다.
-- 남는 인덱스가 동일 정의로 이미 존재하므로 드랍 순간에도 커버되지 않는 쿼리 경로는 없다.

-- focus_sessions (user_id, started_at desc)
-- 유지: focus_sessions_user_started_idx
drop index if exists public.idx_focus_sessions_user_started;

-- hatched_creatures (user_id, hatched_at desc)
-- 유지: hatched_creatures_user_hatched_idx
drop index if exists public.idx_hatched_creatures_user_hatched;
