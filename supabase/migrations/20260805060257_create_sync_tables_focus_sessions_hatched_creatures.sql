-- [사후 복원] 이 파일은 리포를 거치지 않고 대시보드/MCP로 라이브 DB에 직접 적용됐던 마이그레이션을
-- supabase_migrations.schema_migrations 에 저장된 SQL 그대로 되살린 것이다(리포 = 프로덕션 재현 가능 상태 복구용).
-- 주의: 아래 `create table if not exists`는 20260611091144_create_core_schema.sql 이 이미 만든 테이블에
-- 대해 전부 no-op 이었다. 따라서 **실제 라이브 컬럼 타입의 단일 출처는 이 파일이 아니라 core_schema 쪽**이다 —
-- 라이브 확인 결과 planned_seconds / active_seconds / interruption_count 는 아래 표기(bigint)가 아니라
-- integer 이며 `>= 0` check 제약도 그대로 살아있다. 이 파일의 타입 표기를 스키마 근거로 인용하지 말 것.

-- 앱 동기화 대상 테이블. 컬럼명은 SyncModels.swift CodingKeys(snake_case)와 정확히 일치.
-- 데이터/유저 0인 신규 DB → 순수 additive.

create table if not exists public.focus_sessions (
  id                uuid primary key,
  user_id           uuid not null references auth.users(id) on delete cascade,
  started_at        timestamptz not null,
  planned_seconds   bigint not null,
  active_seconds    bigint not null,
  interruption_count bigint not null,
  distracted        boolean not null,
  completed         boolean not null,
  companion_id      uuid,
  mode              text
);

create table if not exists public.hatched_creatures (
  id          uuid primary key,
  user_id     uuid not null references auth.users(id) on delete cascade,
  species     text not null,
  image_name  text not null,
  hatched_at  timestamptz not null
);

-- fetch 경로(.eq user_id + order by 시각) 인덱스
create index if not exists idx_focus_sessions_user_started
  on public.focus_sessions (user_id, started_at desc);
create index if not exists idx_hatched_creatures_user_hatched
  on public.hatched_creatures (user_id, hatched_at desc);

-- PostgREST 접근 권한(행 제한은 RLS가). authenticated(로그인 유저)만.
grant select, insert, update, delete on public.focus_sessions to authenticated;
grant select, insert, update, delete on public.hatched_creatures to authenticated;

-- RLS: 본인 user_id 행만
alter table public.focus_sessions enable row level security;
alter table public.hatched_creatures enable row level security;

drop policy if exists own_select on public.focus_sessions;
drop policy if exists own_insert on public.focus_sessions;
drop policy if exists own_update on public.focus_sessions;
drop policy if exists own_delete on public.focus_sessions;
create policy own_select on public.focus_sessions for select using (auth.uid() = user_id);
create policy own_insert on public.focus_sessions for insert with check (auth.uid() = user_id);
create policy own_update on public.focus_sessions for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy own_delete on public.focus_sessions for delete using (auth.uid() = user_id);

drop policy if exists own_select on public.hatched_creatures;
drop policy if exists own_insert on public.hatched_creatures;
drop policy if exists own_update on public.hatched_creatures;
drop policy if exists own_delete on public.hatched_creatures;
create policy own_select on public.hatched_creatures for select using (auth.uid() = user_id);
create policy own_insert on public.hatched_creatures for insert with check (auth.uid() = user_id);
create policy own_update on public.hatched_creatures for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy own_delete on public.hatched_creatures for delete using (auth.uid() = user_id);
