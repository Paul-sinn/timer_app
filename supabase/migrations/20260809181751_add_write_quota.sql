-- Phase 5 보안 하드닝 B5: 유저당 일일 INSERT 쿼터 (단일 테넌트 DB 고갈 방지)
--
-- 문제
--   RLS는 "누구의 행인가"만 통제한다. "몇 개까지"는 통제하지 않는다.
--   무료 계정 하나 + publishable 키만으로 `POST /rest/v1/focus_sessions`에 배열을 밀어 넣으면
--   user_id를 자기 uid로 맞춘 유효한 행을 초당 수천 개 만들 수 있다. 모든 유저가 같은 Postgres
--   인스턴스를 공유하므로, 한 명이 디스크를 채우면 **전 서비스가 멈춘다**.
--   (B4가 한 행의 크기를 묶었으니, 남은 축은 행의 개수다.)
--
-- ── 구현 방식 선택: 카운터 테이블 (count(*) 아님) ────────────────────────────
--
--   (a) 매 INSERT마다 count(*) — 채택하지 않음
--       cost : 행 단위 트리거면 100행 upsert에 count가 100번 돈다. 문 단위로 낮춰도
--              `count(*) where user_id = ? and created_at > now() - 24h`는 인덱스가 있어야 하고
--              (현재 인덱스는 (user_id, started_at desc) / (user_id, hatched_at desc)뿐이라
--               created_at 기준 인덱스를 새로 만들어야 한다), 스캔량이 그 유저의 하루치 행 수에
--              비례해 **사용량이 늘수록 쓰기가 느려진다**.
--       치명 : created_at은 클라이언트가 보낼 수 있는 컬럼이다(서버 default가 있을 뿐 강제가 아님).
--              공격자가 created_at을 과거로 찍으면 24시간 윈도우 밖으로 빠져 **쿼터가 통째로 무력화**된다.
--              막으려면 created_at을 서버 값으로 덮는 BEFORE INSERT 행 트리거가 또 필요하다
--              (테이블당 트리거 2개 + 인덱스 1개).
--
--   (b) 서버가 소유한 카운터 테이블 — 채택
--       cost : 문(statement) 단위 트리거 1개. 행 수와 무관하게 PK 1건 upsert = O(1).
--              100행을 한 번에 넣든 1행을 넣든 카운터 접근은 1회다.
--       안전 : 버킷 날짜(day)를 서버의 now()로 만든다 → 클라이언트가 조작할 표면이 없다.
--       비용 : 테이블 1개 추가. 단 이 테이블은 @Model 미러가 아니라 **서버 전용 운영 데이터**라
--              SwiftData 스키마/마이그레이션과 완전히 무관하다(CLAUDE.md 영속 데이터 규칙 영향 없음).
--       부가 : 누가 언제 얼마나 쓰는지 그대로 관측된다(악용 탐지에 바로 쓸 수 있다).
--
-- ── SyncService 경로 영향 없음 논증 ──────────────────────────────────────────
--   1) 트리거는 AFTER **INSERT** 전용이다. `.select().eq("user_id", ...).order(...)` 읽기 경로,
--      DELETE(계정 삭제 cascade), UPDATE 경로는 전혀 타지 않는다.
--   2) `.upsert(rows, onConflict:"id")`의 재동기화는 쿼터를 소모하지 않는다.
--      PostgreSQL 규정상 `INSERT ... ON CONFLICT DO UPDATE`의 AFTER INSERT 전이 테이블(new_rows)에는
--      **실제로 삽입된 행만** 들어간다(충돌해서 UPDATE로 간 행은 UPDATE 트리거의 전이 테이블로 간다).
--      따라서 이미 서버에 있는 102행을 다시 push해도 new_rows는 비고, 카운터는 증가하지 않는다.
--      → SyncCoordinator가 로그인마다 호출하는 syncOnLogin()의 멱등성이 그대로 보존된다.
--   3) 0행 INSERT나 전량 충돌 시에도 문 단위 트리거는 뜨지만 new_rows가 비어 카운터 쓰기가 없다.
--   4) 상한(5000)은 정상 사용량의 두 자릿수 배수다(아래 근거).
--
-- ── 상한값 5000/일 근거 ──────────────────────────────────────────────────────
--   실측(현재 프로덕션 DB, 유저 1명):
--     focus_sessions    하루 최대 40행 / 평균 11.33행 (활동일 9일, 총 102행)
--     hatched_creatures 하루 최대 15행 / 평균  5.86행 (활동일 7일, 총  41행)
--     ※ 40행은 DEBUG 빌드의 10초 테스트 세션(63/102행이 planned_seconds=10)이 섞인 개발자 수치라
--        실사용 상한보다 이미 부풀려져 있다.
--   앱 로직상 이론적 최대(릴리스 빌드):
--     free 모드 최소 선택지가 25분(HomeView.durationOptions = 25/50/75분)이므로
--       24h ÷ 25min ≈ 57회/일이 완주 세션의 물리적 상한.
--     pomodoro는 25분 집중 + 5분 휴식 = 기록 1건당 30분 → ≈ 48회/일.
--     hatched_creatures는 완주 세션당 1마리이므로 같은 상한(≈57/일).
--   → 5000 = 이론 상한(57)의 약 87배, 실측 최대(40)의 125배.
--     추가로 **최초 로그인 시 로컬 SwiftData 이력 일괄 업로드(backfill)** 를 흡수해야 하므로
--     "하루치"가 아니라 "누적 이력 한 번에"를 기준으로 잡은 값이다.
--     현재 관측 속도(평균 11.33행/일)라면 약 1.2년치 이력을 한 번에 올려도 통과한다.
--   방어 효과: 행당 실측 평균 100.6바이트(+ 인덱스/튜플 오버헤드 포함 대략 250B)이므로
--     5000행/일 ≈ 1.2MB/일/계정. 무제한(분 단위로 수백 MB)에서 계정당 월 단위로 낮춘다.
--
--   ⚠️ 남은 리스크 — 후속 조치 권고
--     SyncService.pushSessions/pushCreatures는 현재 **한 번의 upsert 문**으로 전량을 보낸다.
--     한 문이 상한을 넘으면 문 전체가 롤백되므로, 로컬 이력이 5000건을 넘는 유저는
--     backfill이 통째로 실패하고 다음 로그인에도 같은 결과가 반복된다(영구 정체).
--     → 클라이언트를 500행 단위 청크 push로 바꾸면, 상한에 걸려도 앞부분은 저장되고
--       나머지는 SyncMerge.diff(합집합)가 다음 로그인에 자연 재시도한다(무손실 지연).
--       청크화 전까지 5000은 "넉넉하지만 무한하지 않은" 절충값이다.
--
-- ── 거부 시 클라이언트 구분 방법 ─────────────────────────────────────────────
--   SQLSTATE 'PT429'로 raise한다. PostgREST는 `PT` + 3자리 코드를 HTTP 상태로 그대로 매핑하므로
--   응답은 **HTTP 429 + JSON {code:"PT429", message:..., detail:..., hint:"hatcho_write_quota_exceeded"}**.
--   클라이언트는 `code == "PT429"` 또는 `hint == "hatcho_write_quota_exceeded"`로 판별하면 된다
--   (B4의 미래 timestamp 거부는 'PT400'이라 서로 구분된다).
--   현재 Swift 호출부는 `try? await sync.pushSessions(...)`로 에러를 삼키므로 **앱은 죽지 않고
--   조용히 스킵**된다(로컬 SwiftData가 단일 소스라 유저 데이터 손실 없음, 업로드만 지연).
--   다만 그만큼 관측도 안 되므로, 후속으로 이 두 코드만 로깅/재시도 백오프 대상으로 잡을 것을 권고한다.

-- ── 1) 카운터 테이블 ─────────────────────────────────────────────────────────
create table if not exists public.write_quota_daily (
  user_id    uuid    not null references auth.users (id) on delete cascade,
  table_name text    not null,
  day        date    not null,
  n          integer not null default 0,
  primary key (user_id, table_name, day)
);

comment on table public.write_quota_daily is
  '유저×테이블×일자 INSERT 카운터(서버 전용). enforce_daily_insert_quota() 트리거만 갱신한다. 앱/@Model과 무관.';

-- CREATE TABLE 시점에 public 스키마 기본 ACL이 anon/authenticated에 arwdDxtm를 붙인다 → 즉시 회수.
-- (B2를 먼저 적용했다면 anon 쪽은 이미 안 붙지만, 순서와 무관하게 안전하도록 명시적으로 회수한다.)
-- service_role은 남긴다 — 운영 조회/수동 리셋용이며, 어차피 전권 관리 키다.
revoke all privileges on table public.write_quota_daily from anon, authenticated;

-- 정책을 하나도 만들지 않는다 = 어떤 API 롤도 행에 접근할 수 없다.
-- 갱신은 아래 SECURITY DEFINER 함수(소유자 postgres = 테이블 소유자 → RLS 우회)만 수행한다.
alter table public.write_quota_daily enable row level security;

-- ── 2) 쿼터 강제 함수 (문 단위, 전이 테이블 사용) ────────────────────────────
create or replace function public.enforce_daily_insert_quota()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_limit int  := (tg_argv[0])::int;
  -- 버킷은 서버 시각(UTC)으로 만든다 — 행에 담긴 클라이언트 값에 의존하지 않는다.
  v_day   date := (now() at time zone 'utc')::date;
  v_user  uuid;
  v_count integer;
begin
  -- 이번 문이 실제로 삽입한 행 수를 유저별로 카운터에 원자적으로 더하고, 더한 뒤 값을 돌려받는다.
  -- 데이터 변경 CTE는 바깥 SELECT가 몇 행을 읽든 항상 끝까지 실행된다(PostgreSQL 보장).
  with bumped as (
    insert into public.write_quota_daily as q (user_id, table_name, day, n)
    select nr.user_id, tg_table_name::text, v_day, count(*)
      from new_rows nr
     where nr.user_id is not null
     group by nr.user_id
    on conflict (user_id, table_name, day)
      do update set n = q.n + excluded.n
    returning q.user_id, q.n
  )
  select b.user_id, b.n
    into v_user, v_count
    from bumped b
   where b.n > v_limit
   order by b.n desc
   limit 1;

  if found then
    -- 문 전체가 롤백된다(카운터 증가분 포함) → 재시도해도 카운터가 이중 증가하지 않는다.
    raise exception
      'daily insert quota exceeded for public.% (limit % rows/day)',
      tg_table_name, v_limit
      using errcode = 'PT429',
            hint    = 'hatcho_write_quota_exceeded',
            detail  = format('table=%s user_id=%s day=%s attempted_total=%s limit=%s',
                             tg_table_name, v_user, v_day, v_count, v_limit);
  end if;

  -- 쿼터 테이블 자신이 DB를 채우는 역설을 막는다: 이 유저의 30일 초과 버킷만 정리.
  -- PK 선두 컬럼(user_id) 기준이라 인덱스 스캔이고, 대상 행 수는 한 자릿수다.
  delete from public.write_quota_daily
   where user_id in (select distinct nr.user_id from new_rows nr where nr.user_id is not null)
     and day < v_day - 30;

  return null;   -- AFTER STATEMENT 트리거의 반환값은 무시된다.
end;
$$;

comment on function public.enforce_daily_insert_quota() is
  '유저당 일일 INSERT 상한 강제(문 단위). 상한은 트리거 인자 tg_argv[0]. 초과 시 SQLSTATE PT429 → HTTP 429.';

-- 새 함수는 public 스키마 기본 ACL로 anon/authenticated EXECUTE가 붙는다 → 회수.
-- 트리거 실행에는 영향 없다(권한 검사는 CREATE TRIGGER 시점에만).
revoke execute on function public.enforce_daily_insert_quota() from public, anon, authenticated;

-- ── 3) 트리거 부착 ───────────────────────────────────────────────────────────
-- FOR EACH STATEMENT + 전이 테이블 → 100행 배치도 카운터 접근 1회.
-- 상한을 바꾸려면 이 트리거만 drop/create 하면 된다(함수 본문 수정 불필요).
drop trigger if exists focus_sessions_daily_quota on public.focus_sessions;
create trigger focus_sessions_daily_quota
  after insert on public.focus_sessions
  referencing new table as new_rows
  for each statement
  execute function public.enforce_daily_insert_quota('5000');

drop trigger if exists hatched_creatures_daily_quota on public.hatched_creatures;
create trigger hatched_creatures_daily_quota
  after insert on public.hatched_creatures
  referencing new table as new_rows
  for each statement
  execute function public.enforce_daily_insert_quota('5000');

-- 알려진 한계(의도된 절충):
--   * 버킷이 UTC 캘린더 일자라 23:59에 5000 + 00:01에 5000 = 2분 만에 10000행이 가능하다.
--     롤링 24시간으로 하려면 시간 단위 버킷 24개를 합산해야 해서 비용/복잡도가 오른다.
--     "무한 → 하루 5000"이 목적이고 2배 오차는 목적을 해치지 않으므로 캘린더 일자로 둔다.
--   * UPDATE에는 쿼터가 없다. 행 수를 늘리지 못하고, 행 크기는 B4의 길이 제약이 묶는다.
--   * profiles에는 걸지 않는다 — auth.users FK 1:1이라 유저당 1행이 상한이다.
