-- Phase 5 보안 하드닝 B3: handle_new_user()를 가입 트랜잭션의 단일 실패점에서 제거
--
-- 문제
--   `on_auth_user_created`는 auth.users의 AFTER INSERT 트리거다. 트리거 함수는 GoTrue의
--   회원가입 INSERT와 **같은 트랜잭션**에서 실행되므로, public.profiles INSERT가 어떤 이유로든
--   실패하면 예외가 전파되어 auth.users INSERT까지 롤백된다 → 회원가입 전체가 500.
--   현재 함수에는 exception 핸들러가 없어서 아래 상황이 전부 "가입 불가"가 된다:
--     - profiles에 이미 같은 id 행이 있음(재시도/중복 이벤트) → unique_violation
--     - profiles에 새로 추가될 제약 위반(B4의 display_name 길이 상한 등)
--     - profiles 테이블 잠금/디스크 부족/일시 오류
--   프로필 행은 **부가 정보**다. 없다고 앱이 못 도는데(아래 참고) 가입을 막을 이유가 없다.
--
-- 참고: iOS 앱은 현재 public.profiles를 읽지도 쓰지도 않는다.
--   SyncModels.swift에 ProfileRow 타입이 선언되어 있으나 어디에서도 사용되지 않고,
--   코드베이스 전체에 `.from("profiles")` 호출이 없다(SyncService는 focus_sessions/hatched_creatures만).
--   → 프로필 생성 실패의 실사용 영향은 현시점 0. 가입을 지키는 편이 압도적으로 이득이다.
--
-- 설계
--   1) INSERT를 중첩 BEGIN/EXCEPTION 블록으로 감싸고, 실패해도 `return new`로 가입은 통과시킨다.
--   2) `on conflict (id) do nothing` — 예외 핸들러에 도달하기 전에 가장 흔한 실패(중복)를 무해화.
--      (핸들러 진입은 서브트랜잭션 롤백을 유발하므로, 예상 가능한 경우는 미리 걸러내는 편이 싸다.)
--   3) 실패는 조용히 삼키지 않고 `raise warning`으로 Postgres 로그에 남긴다
--      (Supabase Logs → Postgres에서 'handle_new_user'로 검색 가능). 관측 없는 무시는 금물.
--   4) 기존 보안 속성 유지: security definer + set search_path = '' + 정규화된 테이블 참조.
--
-- 주의: exception 블록은 호출마다 서브트랜잭션(savepoint)을 연다. 가입 경로는 초당 수 회 수준이라
--       비용은 무시할 수 있다(초고빈도 쓰기 경로였다면 재고 대상).

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  begin
    insert into public.profiles (id, display_name)
    values (
      new.id,
      coalesce(
        new.raw_user_meta_data ->> 'name',
        new.raw_user_meta_data ->> 'full_name'
      )
    )
    on conflict (id) do nothing;
  exception
    when others then
      -- 프로필 생성 실패가 회원가입을 막아서는 안 된다. 로그만 남기고 통과시킨다.
      -- (사용자는 정상 가입되고, 프로필 행은 이후 로그인 시 upsert로 자가 치유할 수 있다.)
      raise warning 'handle_new_user: profile insert failed for user % — %: %',
        new.id, sqlstate, sqlerrm;
  end;

  return new;
end;
$$;

comment on function public.handle_new_user() is
  '신규 auth.users → public.profiles 자동 생성. 실패해도 가입은 통과(예외 삼키고 warning 로그).';

-- 트리거 재생성 불필요 — 확인 완료.
--   `on_auth_user_created`는 pg_trigger.tgfoid로 함수 **OID**를 참조하고,
--   `create or replace function`은 기존 OID를 그대로 유지한다(새 함수를 만들지 않는다).
--   실측: pg_trigger 조인 결과 on_auth_user_created → public.handle_new_user, tgenabled='O'.
--   따라서 본문 교체만으로 트리거는 즉시 새 본문을 쓴다. drop/create trigger는 하지 않는다
--   (auth.users에 대한 DDL은 불필요한 위험).

-- 함수 실행 권한 재적용(멱등).
--   `create or replace function`은 기존 ACL을 보존하므로 실측상 이미
--   {postgres=X, service_role=X}이고 anon/authenticated는 없다. 그래도 명시적으로 재선언한다:
--   (a) 이 파일만 읽어도 의도가 드러나고, (b) 다른 환경(로컬 DB 재생성 등)에서 함수가
--   `create`로 처음 만들어지면 public 스키마 기본 ACL이 anon/authenticated에 EXECUTE를 주기 때문.
--   트리거 실행에는 영향 없다(트리거 함수 권한 검사는 CREATE TRIGGER 시점에만 이뤄진다).
--   service_role은 남겨둔다 — 이미 전권 관리 롤이고, plpgsql 트리거 함수는 직접 호출 시 어차피 에러다.
revoke execute on function public.handle_new_user() from public, anon, authenticated;
