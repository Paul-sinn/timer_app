-- Phase 3 step 1: 핵심 클라우드 스키마 (profiles / focus_sessions / hatched_creatures)
-- 로컬 SwiftData 모델 1:1 미러. PK는 클라이언트 생성 UUID(로컬 id와 동일) → idempotent 동기화.

-- profiles: auth.users 1:1 확장
create table public.profiles (
  id           uuid primary key references auth.users (id) on delete cascade,
  display_name text,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
comment on table public.profiles is '사용자 프로필. auth.users와 1:1.';

-- focus_sessions: FocusSessionRecord 미러
create table public.focus_sessions (
  id                 uuid primary key,
  user_id            uuid not null references auth.users (id) on delete cascade,
  started_at         timestamptz not null,
  planned_seconds    integer not null check (planned_seconds >= 0),
  active_seconds     integer not null check (active_seconds >= 0),
  interruption_count integer not null default 0 check (interruption_count >= 0),
  distracted         boolean not null default false,
  completed          boolean not null default false,
  created_at         timestamptz not null default now()
);
comment on table public.focus_sessions is '끝난 집중 세션. 통계 원자료.';

-- hatched_creatures: HatchedCreatureRecord 미러
create table public.hatched_creatures (
  id         uuid primary key,
  user_id    uuid not null references auth.users (id) on delete cascade,
  species    text not null,
  image_name text not null,
  hatched_at timestamptz not null,
  created_at timestamptz not null default now()
);
comment on table public.hatched_creatures is '부화 이력. 생명체 1마리 = 1행. species는 CreatureSpecies.rawValue.';

-- 인덱스: 사용자별 조회 + FK 인덱스 겸용
create index focus_sessions_user_started_idx
  on public.focus_sessions (user_id, started_at desc);
create index hatched_creatures_user_hatched_idx
  on public.hatched_creatures (user_id, hatched_at desc);

-- Data API 노출: authenticated 롤에 명시적 GRANT (anon은 부여 안 함). 행 접근은 RLS가 통제.
grant select, insert, update, delete on public.profiles          to authenticated;
grant select, insert, update, delete on public.focus_sessions    to authenticated;
grant select, insert, update, delete on public.hatched_creatures to authenticated;

-- RLS 활성화
alter table public.profiles          enable row level security;
alter table public.focus_sessions    enable row level security;
alter table public.hatched_creatures enable row level security;

-- profiles 정책 (소유자 = id)
create policy "profiles_select_own" on public.profiles
  for select to authenticated using ((select auth.uid()) = id);
create policy "profiles_insert_own" on public.profiles
  for insert to authenticated with check ((select auth.uid()) = id);
create policy "profiles_update_own" on public.profiles
  for update to authenticated using ((select auth.uid()) = id) with check ((select auth.uid()) = id);
create policy "profiles_delete_own" on public.profiles
  for delete to authenticated using ((select auth.uid()) = id);

-- focus_sessions 정책 (소유자 = user_id)
create policy "focus_sessions_select_own" on public.focus_sessions
  for select to authenticated using ((select auth.uid()) = user_id);
create policy "focus_sessions_insert_own" on public.focus_sessions
  for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "focus_sessions_update_own" on public.focus_sessions
  for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "focus_sessions_delete_own" on public.focus_sessions
  for delete to authenticated using ((select auth.uid()) = user_id);

-- hatched_creatures 정책 (소유자 = user_id)
create policy "hatched_creatures_select_own" on public.hatched_creatures
  for select to authenticated using ((select auth.uid()) = user_id);
create policy "hatched_creatures_insert_own" on public.hatched_creatures
  for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "hatched_creatures_update_own" on public.hatched_creatures
  for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "hatched_creatures_delete_own" on public.hatched_creatures
  for delete to authenticated using ((select auth.uid()) = user_id);
