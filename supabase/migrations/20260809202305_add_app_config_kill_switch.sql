-- 원격 기능 플래그(킬스위치).
--
-- 문제: DB가 과부하로 흔들려도 클라이언트 동기화를 멈출 방법이 앱 업데이트뿐이다.
-- 심사 1~2일 + 배포 + 유저 업데이트까지 기다리는 동안 서버는 계속 맞는다.
-- 이 테이블의 값 하나를 바꾸면 30초 안에 전 클라이언트의 원격 동기화가 멈춘다.
-- 앱은 로컬 SwiftData로 정상 동작하고(단일 소스), 서버만 쉰다.
--
-- key/value(jsonb) 구조라 플래그가 늘어도 스키마 변경이 필요 없다.

create table if not exists public.app_config (
  key        text primary key,
  value      jsonb not null,
  updated_at timestamptz not null default now()
);

comment on table public.app_config is
  '원격 기능 플래그(킬스위치). 앱 업데이트 없이 서버에서 기능을 끈다. 모든 롤에 읽기 전용 공개.';

-- B2 이후 public 신규 테이블은 anon에 기본 grant가 붙지 않는다(alter default privileges).
-- 신규 테이블 체크리스트대로 명시적으로 최소 권한만 준다: SELECT 뿐, 쓰기는 아무도 못 한다.
revoke all privileges on table public.app_config from anon, authenticated;
grant select on table public.app_config to anon, authenticated;

alter table public.app_config enable row level security;

-- 비로그인 상태에서도 읽혀야 한다 — 킬스위치는 로그인 전에도 유효해야 하기 때문.
-- 민감 정보가 아니므로 전체 공개 읽기가 맞다.
drop policy if exists app_config_read_all on public.app_config;
create policy app_config_read_all on public.app_config
  for select to anon, authenticated using (true);

-- 쓰기 정책을 하나도 만들지 않는다 = API 롤로는 값을 바꿀 수 없다.
-- 조작은 Supabase 대시보드(또는 service_role)에서만 한다.

drop trigger if exists app_config_set_updated_at on public.app_config;
create trigger app_config_set_updated_at
  before update on public.app_config
  for each row execute function public.set_updated_at();

-- 기본값: 켜짐. 끄려면 대시보드에서 value를 false로 바꾸면 된다.
insert into public.app_config (key, value) values
  ('sync_enabled', 'true'::jsonb)
on conflict (key) do nothing;
