-- Phase 5 보안 하드닝 B4: 값 범위 상한 제약 (하한만 있던 구멍 메우기)
--
-- 문제
--   기존 제약은 `planned_seconds >= 0`, `active_seconds >= 0`, `interruption_count >= 0` 뿐이다.
--   상한이 없어서 1000시간짜리 세션, 서기 2999년 started_at, 1900년 hatched_at이 전부 통과한다.
--   지금은 통계가 개인용이라 티가 안 나지만, 리더보드/랭킹을 붙이는 순간 클라이언트가
--   임의의 JSON을 보내는 것만으로 1위가 된다. 텍스트 컬럼에는 길이 상한조차 없다.
--
-- 사전 검증(적용 전 실측, execute_sql SELECT):
--   focus_sessions   102행 → 아래 모든 제약 통과 (fs_pass_all = 102)
--     started_at  min 2026-06-16T09:48:51Z / max 2026-08-08T01:07:04Z
--     planned_seconds  min 10  / max 4500   (분포: 10×63, 30×8, 1500×16, 3000×14, 4500×1)
--     active_seconds   min 1   / max 4500
--     interruption_count min 0 / max 2
--     mode 길이 max 8 ('free' | 'pomodoro' | null)
--   hatched_creatures 41행 → 통과 (hc_pass_all = 41)
--     hatched_at  min 2026-06-16T09:48:48Z / max 2026-08-05T04:05:30Z
--     species 길이 max 9, image_name 길이 max 14
--   profiles 1행 → 통과 (display_name null, settings 5바이트)
--   → 143행 전부 통과하므로 `not valid` 없이 즉시 검증(validated)으로 추가한다.
--     (테이블이 각각 112kB/64kB라 ACCESS EXCLUSIVE 락 + 전체 스캔이 순간에 끝난다.
--      행이 수백만 단위가 되면 `add constraint ... not valid` → `validate constraint` 2단계로 갈 것.)
--
-- ─────────────────────────────────────────────────────────────────────────────
-- now()를 CHECK에 쓸 수 없는 문제 → CHECK(고정 경계) + 트리거(상대 경계) 2단 구성
--
--   CHECK 제약식은 IMMUTABLE이어야 한다. now()/current_timestamp는 STABLE이라 거부된다.
--   (실측: pg_column_size도 provolatile='s'라 CHECK에 못 쓴다 → settings 크기는 length(settings::text)로.
--    반면 jsonb_out·length(text)·octet_length(text)는 전부 'i'(immutable)라 안전하다.)
--
--   선택지 비교
--     (a) 고정 상한 날짜만 사용 — 예: started_at < '2100-01-01'
--         + 선언적, 런타임 비용 0, 기존 행 검증 가능
--         − "내년" 스푸핑을 못 막는다. 그렇다고 '2027-01-01'처럼 타이트하게 잡으면
--           그 날짜에 **모든 쓰기가 죽는 시한폭탄**이 된다(최악의 실패 모드).
--     (b) 트리거만 사용 — now() 기준 상대 검사
--         + 만료 없음, "지금보다 미래" 판정 가능
--         − 선언적이지 않고 기존 행을 검증하지 않는다. 행마다 함수 호출 비용.
--
--   결론: 둘 다 쓴다. 역할을 나누면 각자의 단점이 사라진다.
--     CHECK   = 시대 착오 쓰레기 차단용 절대 경계 [2020-01-01, 2100-01-01).
--               2020은 앱이 존재하지 않던 시점이라 안전한 하한이고, 2100은 시한폭탄이 되지 않을
--               만큼 멀다. 기존 143행 검증도 여기서 이뤄진다.
--     트리거  = "now() + 1일보다 미래 금지" 상대 경계. 실제 조작 방어는 이쪽이 담당한다.
--               +1일 여유는 기기 시계 오차/타임존 혼동으로 인한 정상 유저 오탐을 막기 위함
--               (started_at은 클라이언트 Date()에서 오고, 사용자가 기기 시계를 직접 바꿀 수도 있다).
--               쿼리를 하지 않는 순수 비교라 비용은 무시 가능하다.
-- ─────────────────────────────────────────────────────────────────────────────
--
-- SyncService 경로 영향 없음 논증
--   `.upsert(rows, onConflict:"id")`가 보내는 값은 SessionManager가 만든 값뿐이다:
--     planned_seconds ∈ {1500, 3000, 4500} (릴리스 durationOptions) 또는 1500(포모도로 블록),
--     DEBUG 빌드에 한해 10. 전부 [0, 86400] 안.
--     active_seconds = min(경과초 + 보너스, plannedSeconds) — recompute()에서 캡되므로 ≤ planned ≤ 4500.
--     interruption_count = 포그라운드 복귀 시 1씩 증가 — 세션당 현실적으로 한 자릿수(실측 max 2).
--     started_at / hatched_at = 과거 시각. SELECT 경로(`.select().eq().order()`)는 제약과 무관.
--   → 정상 클라이언트가 만드는 어떤 페이로드도 아래 제약에 걸리지 않는다.

-- ── focus_sessions: 수치 상한 ────────────────────────────────────────────────
-- 86400초 = 24시간. "한 세션은 하루를 넘을 수 없다"는 물리적 상식 경계다.
-- 현재 UI 최대치(4500초)의 19배 여유 → 향후 커스텀 시간/장시간 모드가 생겨도 마이그레이션이 필요 없다.
-- (리더보드 공정성은 이 제약이 아니라 제품 규칙 — 예: 일일 집계 상한 — 으로 다뤄야 한다.
--  planned/active 둘 다 클라이언트가 정하는 값이라 DB 제약만으로는 "정직한 값"을 보장할 수 없다.)
alter table public.focus_sessions
  add constraint focus_sessions_planned_seconds_max
  check (planned_seconds <= 86400);

alter table public.focus_sessions
  add constraint focus_sessions_active_seconds_max
  check (active_seconds <= 86400);

-- 이탈 1회에는 최소한 백그라운드↔포그라운드 왕복이 필요하다. 24시간 세션이라도 만 번은 비현실적.
alter table public.focus_sessions
  add constraint focus_sessions_interruption_count_max
  check (interruption_count <= 10000);

-- ── 의도적으로 추가하지 않은 제약: active_seconds <= planned_seconds ──────────
--   앱 로직상으로는 **현재 성립한다**. SessionManager.recompute()가
--     activeSecondsLive = min(s.activeSeconds(now:) + bonusSeconds, s.plannedSeconds)
--   로 캡하고, complete()도 accumulatedActiveSeconds = plannedSeconds로 고정한다.
--   free 모드도 스톱워치가 아니라 "목표 시간 카운트다운"이라 초과가 발생하지 않는다.
--   실측으로도 102행 중 위반 0행(violate_active_gt_planned = 0).
--
--   그래도 걸지 않는 이유:
--     1) 보안 가치가 사실상 0이다. planned_seconds도 클라이언트가 보내는 값이라,
--        공격자는 planned=86400 / active=86400으로 보내면 그만이다. 이 제약이 막는 것은
--        "앱 버그"뿐이고, 앱 버그는 이미 유닛 테스트의 영역이다.
--     2) 위험은 실재한다. 초과 집중(overtime)·스톱워치 모드·포모도로 블록 누적 합산 같은
--        제품 변경이 들어오는 순간 이 관계가 깨진다. 그러면 upsert가 400으로 실패하고,
--        SyncService 호출부는 전부 `try?`로 에러를 삼키므로 **조용히 동기화만 끊긴다**.
--        탐지가 늦고 유저 데이터가 클라우드에 안 올라가는, 데이터 손실에 인접한 실패다.
--     3) 이득(앱 버그 탐지) < 위험(무성한 동기화 중단). CLAUDE.md의 "확신 없으면 걸지 말 것" 적용.
--   → 이 관계를 강제하고 싶다면 DB가 아니라 EggtimerTests(SessionManagerTests)에서 하는 편이 옳다.

-- ── 시각 절대 경계 (IMMUTABLE 리터럴) ────────────────────────────────────────
-- 리터럴에 '+00' 오프셋을 명시해, DDL 실행 세션의 TimeZone과 무관하게 같은 절대 시각으로
-- 상수 폴딩되게 한다(오프셋을 빼면 세션 타임존에 따라 경계가 몇 시간 흔들린다).
alter table public.focus_sessions
  add constraint focus_sessions_started_at_range
  check (started_at >= timestamptz '2020-01-01 00:00:00+00'
     and started_at <  timestamptz '2100-01-01 00:00:00+00');

alter table public.hatched_creatures
  add constraint hatched_creatures_hatched_at_range
  check (hatched_at >= timestamptz '2020-01-01 00:00:00+00'
     and hatched_at <  timestamptz '2100-01-01 00:00:00+00');

-- ── 텍스트/JSON 크기 상한 ────────────────────────────────────────────────────
-- 왜 중요한가: 행 개수 쿼터(B5)는 "행 수"만 막는다. text/jsonb 컬럼에 상한이 없으면
-- **단 한 행으로 1GB**를 넣어 DB를 채울 수 있다(TOAST). 쓰기 쿼터보다 이쪽이 더 싼 공격이다.
-- UPDATE에도 적용되므로 "행 하나 만들고 계속 키우기"도 함께 막힌다.
--
-- 상한 근거(실측 최대값 대비 여유):
--   species    max 9자  (가장 긴 rawValue는 'whiteTiger' 10자)      → 64자 = 6배 이상
--   image_name max 14자 (에셋 이름)                                  → 64자 = 4배 이상
--   mode       max 8자  ('pomodoro')                                 → 64자 = 8배
--   display_name null   (Apple/Google 표시 이름)                     → 500자
--   settings   5바이트  ('{}')                                       → 16KB
alter table public.hatched_creatures
  add constraint hatched_creatures_species_len
  check (length(species) between 1 and 64);

alter table public.hatched_creatures
  add constraint hatched_creatures_image_name_len
  check (length(image_name) between 1 and 64);

-- mode는 nullable(구버전 행은 null). 값 목록(free/pomodoro) enum 제약은 **일부러 걸지 않는다** —
-- 새 모드를 추가하는 순간 구 DB/신 앱 조합에서 동기화가 조용히 깨진다. 길이 상한이면 충분하다.
alter table public.focus_sessions
  add constraint focus_sessions_mode_len
  check (mode is null or length(mode) between 1 and 64);

-- profiles는 앱이 아직 읽지도 쓰지도 않지만(`.from("profiles")` 호출 0건),
-- RLS 정책상 authenticated가 **자기 행을 UPDATE할 수 있다**. settings jsonb에 상한이 없으면
-- 로그인 계정 하나로 임의 크기 데이터를 저장할 수 있다 → 함께 막는다.
-- pg_column_size는 STABLE이라 CHECK에 쓸 수 없어 length(settings::text)를 쓴다(jsonb_out·length 모두 IMMUTABLE).
alter table public.profiles
  add constraint profiles_display_name_len
  check (display_name is null or length(display_name) <= 500);

alter table public.profiles
  add constraint profiles_settings_size
  check (length(settings::text) <= 16384);

-- ── 상대 시각 경계: "미래 timestamp 금지" 트리거 ─────────────────────────────
-- CHECK로 표현 불가능한 now() 기준 검사만 담당한다. 쿼리 없이 값 비교만 하므로 사실상 공짜다.
-- 검사 대상 컬럼명은 트리거 인자로 받아 테이블마다 재사용한다(to_jsonb로 동적 접근).
create or replace function public.reject_future_timestamp()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_column text := tg_argv[0];
  v_value  timestamptz;
  -- 기기 시계 오차/타임존 혼동 허용치. 이보다 미래는 정상 클라이언트가 만들 수 없다.
  v_slack  interval := interval '1 day';
begin
  v_value := (to_jsonb(new) ->> v_column)::timestamptz;

  if v_value is not null and v_value > now() + v_slack then
    raise exception
      '%.% is too far in the future (% > now() + %)',
      tg_table_name, v_column, v_value, v_slack
      using errcode = 'PT400',
            hint    = 'hatcho_future_timestamp_rejected';
  end if;

  return new;
end;
$$;

comment on function public.reject_future_timestamp() is
  '지정 컬럼(tg_argv[0])의 timestamptz가 now()+1일을 넘으면 거부. CHECK가 now()를 못 쓰는 문제 보완.';

-- 새로 만든 함수는 public 스키마 기본 ACL 때문에 anon/authenticated에 EXECUTE가 붙는다 → 회수.
-- (트리거 실행에는 영향 없음 — 권한 검사는 CREATE TRIGGER 시점에만 이뤄진다.)
revoke execute on function public.reject_future_timestamp() from public, anon, authenticated;

-- upsert의 충돌 분기(=UPDATE)도 검사해야 하므로 INSERT OR UPDATE 둘 다 건다.
drop trigger if exists focus_sessions_reject_future_started_at on public.focus_sessions;
create trigger focus_sessions_reject_future_started_at
  before insert or update on public.focus_sessions
  for each row execute function public.reject_future_timestamp('started_at');

drop trigger if exists hatched_creatures_reject_future_hatched_at on public.hatched_creatures;
create trigger hatched_creatures_reject_future_hatched_at
  before insert or update on public.hatched_creatures
  for each row execute function public.reject_future_timestamp('hatched_at');
