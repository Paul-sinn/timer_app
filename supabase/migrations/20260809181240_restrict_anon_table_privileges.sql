-- Phase 5 보안 하드닝 B2: anon/authenticated 테이블 권한 최소화 (RLS로 못 막는 권한 제거)
--
-- 배경 — 왜 필요한가
--   최초 마이그레이션(20260611091144)은 authenticated에게 select/insert/update/delete만
--   명시적으로 grant했다. 그런데 Supabase 프로젝트에는 플랫폼 기본값으로
--     alter default privileges in schema public grant all on tables to anon, authenticated, service_role
--   이 걸려 있어서, CREATE TABLE 시점에 anon·authenticated가 자동으로 전권(arwdDxtm)을 받았다.
--   실측(pg_default_acl / information_schema.role_table_grants):
--     3테이블 × {anon, authenticated} 모두 DELETE,INSERT,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE
--
--   이 중 TRUNCATE(D)·REFERENCES(x)·TRIGGER(t)는 **RLS가 전혀 관여하지 않는 권한**이다.
--     - TRUNCATE : 행 단위 정책을 우회하고 테이블을 통째로 비운다. RLS 정책이 아무리 촘촘해도 무의미.
--     - REFERENCES: 해당 테이블을 참조하는 FK를 만들 수 있다 → 타 테이블을 통한 행 존재 유추/삭제 방해.
--     - TRIGGER   : 테이블에 트리거를 붙일 수 있다(자신이 EXECUTE 가능한 함수 대상).
--                   현재 anon·authenticated는 public 스키마에 CREATE 권한이 없어(nspacl: anon=U/authenticated=U)
--                   임의 함수를 새로 만들지는 못하지만, 이미 EXECUTE 가능한 public.set_updated_at 같은
--                   함수를 붙여 쓰기 경로를 교란하는 것은 가능하다.
--   PostgREST가 노출하는 표준 동사(GET/POST/PATCH/DELETE)로 TRUNCATE를 직접 호출할 수는 없지만,
--   SECURITY INVOKER RPC 함수가 하나라도 생기면 그 함수는 호출자 롤 권한으로 실행된다.
--   즉 "지금 당장 뚫린다"기보다 **정당한 용도가 0인데 파괴력만 큰 권한**이므로 제거한다(심층 방어).
--
-- 앱 영향 없음 논증
--   1) anon 권한 회수: public.* 3테이블에 anon 대상 RLS 정책이 0개다(정책은 전부 `to authenticated`).
--      RLS가 켜진 테이블에서 정책이 없는 롤은 select/insert/update/delete가 **항상 0행/거부**다.
--      따라서 anon의 CRUD 권한은 이미 실질 무용 — 회수해도 동작 차이가 없다(에러 문구만
--      "빈 결과"에서 "permission denied"로 바뀐다).
--   2) iOS 앱은 로그인 전에 테이블을 건드리지 않는다. SyncCoordinator의 모든 경로가
--      `guard let userId = auth.currentUserID else { return }`로 막혀 있고, 테이블 접근은
--      SyncService(= 로그인 후 authenticated JWT)에서만 일어난다.
--   3) Edge Function `delete-account`는 anon 키로 클라이언트를 만들지만, 그 클라이언트로는
--      `auth.getUser()`(GoTrue)만 호출한다. PostgREST 테이블 접근이 아니다.
--      실제 삭제는 service_role로 `auth.admin.deleteUser()` → FK cascade. service_role 권한은 건드리지 않는다.
--   4) authenticated는 select/insert/update/delete를 그대로 유지한다.
--      → SyncService의 `.from(...).upsert(rows, onConflict:"id")`(INSERT+UPDATE)와
--        `.from(...).select().eq("user_id", ...).order(...)`(SELECT)는 영향 없음.
--
-- ─────────────────────────────────────────────────────────────────────────────
-- 신규 테이블 생성 시 체크리스트 (이 사고를 반복하지 않기 위해)
--   [ ] 1. `alter table <t> enable row level security;`  ← 빼먹으면 전 세계 공개
--   [ ] 2. 필요한 롤별 정책을 4종(select/insert/update/delete) 명시적으로 작성.
--          정책이 없는 롤은 접근 불가라는 점을 "권한 회수 대신"으로 쓰지 말 것 — 권한도 같이 줄인다.
--   [ ] 3. `revoke all on table <t> from anon, authenticated;` 로 기본 grant를 초기화한 뒤,
--          실제로 필요한 것만 `grant select, insert, update, delete ... to authenticated;`
--          (TRUNCATE/REFERENCES/TRIGGER는 앱이 절대 쓰지 않는다 — 주지 말 것)
--   [ ] 4. user_id 컬럼에 인덱스(정책 조건이 인덱스를 타야 RLS가 느려지지 않는다)
--   [ ] 5. SECURITY DEFINER 함수를 만들면 `set search_path = ''` +
--          `revoke execute on function ... from public, anon, authenticated;`
-- ─────────────────────────────────────────────────────────────────────────────

-- 1) anon: 3테이블에서 모든 권한 회수 (위 논증 1·2·3)
revoke all privileges on table
  public.profiles,
  public.focus_sessions,
  public.hatched_creatures
from anon;

-- 2) authenticated: RLS로 통제 불가능한 3종만 회수. CRUD 4종은 유지(앱이 쓴다).
revoke truncate, references, trigger on table
  public.profiles,
  public.focus_sessions,
  public.hatched_creatures
from authenticated;

-- 3) 앱이 쓰는 권한 재확인(멱등 — 위 revoke가 과도했을 경우의 안전망 겸 의도 문서화)
grant select, insert, update, delete on table
  public.profiles,
  public.focus_sessions,
  public.hatched_creatures
to authenticated;

-- 4) 향후 신규 테이블 기본값 좁히기
--
--    주의(플랫폼 충돌 가능성):
--      * `alter default privileges`는 **FOR ROLE을 생략하면 현재 롤(=마이그레이션 실행 롤 postgres)**
--        이 앞으로 만드는 객체에만 적용된다. 실측상 public 스키마에는 grantor가 두 개 있다:
--          postgres      → {anon,authenticated,service_role}=arwdDxtm   ← 아래에서 좁히는 대상
--          supabase_admin→ {anon,authenticated,service_role}=arwdDxtm   ← 우리가 건드릴 수 없음
--        즉 supabase_admin이 만드는 테이블(플랫폼 내부 기능)은 여전히 기본 grant를 받는다.
--        우리 마이그레이션/CLI/Studio는 postgres로 생성하므로 실질 커버리지는 충분하다.
--      * 이후 Studio 테이블 에디터로 새 테이블을 만들면 **anon에 자동 grant가 안 붙는다**.
--        anon 공개가 필요한 테이블(예: 공개 랭킹 뷰)은 반드시 명시적으로 grant해야 한다.
--        이것은 버그가 아니라 의도된 "기본 거부"다. 위 체크리스트 3번 참고.
--
--    보수적으로: authenticated의 CRUD 기본값은 **건드리지 않는다**.
--    (신규 테이블이 API에서 안 보이면 원인 파악이 어려운 실패가 되고, RLS가 이미 행 단위 게이트다.
--     반면 TRUNCATE/REFERENCES/TRIGGER는 어떤 신규 테이블에서도 정당한 용도가 없다.)
alter default privileges in schema public
  revoke all on tables from anon;

alter default privileges in schema public
  revoke truncate, references, trigger on tables from authenticated;

-- 참고(이번 범위 아님, 의도적 보류):
--   함수 기본 권한도 `{anon,authenticated}=X`로 열려 있다(pg_default_acl objtype='f').
--   `alter default privileges ... revoke all on functions from anon`은 pg_graphql 등
--   확장/플랫폼이 public에 만드는 함수까지 영향을 줄 수 있어 여기서는 손대지 않는다.
--   대신 개별 SECURITY DEFINER 함수마다 명시적으로 revoke 한다(체크리스트 5번, B3 참고).

comment on table public.profiles is
  '사용자 프로필. auth.users와 1:1. 권한: authenticated CRUD만(anon 전면 차단, TRUNCATE/REFERENCES/TRIGGER 없음).';
comment on table public.focus_sessions is
  '끝난 집중 세션. 통계 원자료. 권한: authenticated CRUD만(anon 전면 차단, TRUNCATE/REFERENCES/TRIGGER 없음).';
comment on table public.hatched_creatures is
  '부화 이력. 생명체 1마리 = 1행. species는 CreatureSpecies.rawValue. 권한: authenticated CRUD만(anon 전면 차단).';
