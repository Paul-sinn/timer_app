# Supabase 보안 하드닝 롤백 절차 (2026-08-09 적용분)

적용된 마이그레이션 5건을 되돌리는 SQL. **역순으로** 실행한다(B5 → B4 → B3 → B2 → 인덱스).
각 블록은 독립적이라 문제가 되는 것만 골라 되돌려도 된다.

적용 시점 상태: auth.users 1 / focus_sessions 102 / hatched_creatures 41 / profiles 1.

---

## 증상별 빠른 판단

| 증상 | 원인 후보 | 되돌릴 것 |
|---|---|---|
| 앱에서 세션·부화 저장이 안 됨. 서버 응답 **429** + `hint: hatcho_write_quota_exceeded` | 쓰기 쿼터 | B5 |
| 저장 실패. 응답 **400** + `hint: hatcho_future_timestamp_rejected` | 기기 시계가 하루 이상 빠름 | B4 트리거만 |
| 저장 실패. SQLSTATE **23514** (check_violation) | 값 상한 제약 | B4 제약만 |
| 저장·조회 전부 실패. SQLSTATE **42501** (permission denied) | 권한 회수 | B2 |
| **회원가입**이 500으로 실패 | B3는 가입을 더 잘 통과시키는 방향이라 원인일 가능성 낮음 | 먼저 Postgres 로그에서 `handle_new_user` 검색 |

> 쿼터/제약 거부는 **앱을 죽이지 않는다.** 로컬 SwiftData가 단일 소스이고 동기화는 id 기준
> 합집합이라, 업로드만 지연되고 다음 로그인에 자연 복구된다. 데이터 손실 경로가 아니다.

---

## B5 — 쓰기 쿼터

상한만 조정하려면 롤백하지 말고 트리거만 재생성하면 된다(함수 본문 불변):

```sql
drop trigger if exists focus_sessions_daily_quota on public.focus_sessions;
create trigger focus_sessions_daily_quota
  after insert on public.focus_sessions
  referencing new table as new_rows
  for each statement
  execute function public.enforce_daily_insert_quota('20000');   -- 새 상한
```

완전 제거:

```sql
drop trigger if exists focus_sessions_daily_quota    on public.focus_sessions;
drop trigger if exists hatched_creatures_daily_quota on public.hatched_creatures;
drop function if exists public.enforce_daily_insert_quota();
drop table if exists public.write_quota_daily;
```

## B4 — 값 범위 제약

트리거(미래 시각 거부)만 끄기 — 기기 시계 문제일 때:

```sql
drop trigger if exists focus_sessions_reject_future_started_at    on public.focus_sessions;
drop trigger if exists hatched_creatures_reject_future_hatched_at on public.hatched_creatures;
drop function if exists public.reject_future_timestamp();
```

제약까지 전부 제거:

```sql
alter table public.focus_sessions
  drop constraint if exists focus_sessions_planned_seconds_max,
  drop constraint if exists focus_sessions_active_seconds_max,
  drop constraint if exists focus_sessions_interruption_count_max,
  drop constraint if exists focus_sessions_started_at_range,
  drop constraint if exists focus_sessions_mode_len;
alter table public.hatched_creatures
  drop constraint if exists hatched_creatures_hatched_at_range,
  drop constraint if exists hatched_creatures_species_len,
  drop constraint if exists hatched_creatures_image_name_len;
alter table public.profiles
  drop constraint if exists profiles_display_name_len,
  drop constraint if exists profiles_settings_size;
```

> 원래부터 있던 `*_check`(하한 `>= 0`) 3개는 이 목록에 없다 — 건드리지 말 것.

## B3 — handle_new_user 원복

되돌리면 profiles INSERT 실패가 다시 **회원가입 전체를 500으로 만든다.** 권장하지 않는다.

```sql
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'name',
                           new.raw_user_meta_data ->> 'full_name'));
  return new;
end; $$;
revoke execute on function public.handle_new_user() from public, anon, authenticated;
```

## B2 — 권한 원복

되돌리면 anon이 TRUNCATE 권한을 다시 갖는다(RLS로 못 막는 권한).

```sql
grant select, insert, update, delete, truncate, references, trigger on table
  public.profiles, public.focus_sessions, public.hatched_creatures
to anon, authenticated;

alter default privileges in schema public grant all on tables to anon;
alter default privileges in schema public
  grant truncate, references, trigger on tables to authenticated;
```

## 중복 인덱스 원복

```sql
create index if not exists idx_focus_sessions_user_started
  on public.focus_sessions (user_id, started_at desc);
create index if not exists idx_hatched_creatures_user_hatched
  on public.hatched_creatures (user_id, hatched_at desc);
```

---

## 롤백 후 확인

```sql
-- 제약 목록
select conrelid::regclass::text, conname, pg_get_constraintdef(oid)
from pg_constraint where connamespace='public'::regnamespace and contype='c' order by 1,2;

-- 트리거 목록
select c.relname, t.tgname, p.proname from pg_trigger t
join pg_class c on c.oid=t.tgrelid join pg_namespace n on n.oid=c.relnamespace
join pg_proc p on p.oid=t.tgfoid
where n.nspname='public' and not t.tgisinternal order by 1,2;

-- 권한
select table_name, grantee, string_agg(privilege_type,',' order by privilege_type)
from information_schema.role_table_grants
where table_schema='public' and grantee in ('anon','authenticated')
group by 1,2 order by 1,2;

-- 데이터 무손상
select (select count(*) from public.focus_sessions)    as sessions,
       (select count(*) from public.hatched_creatures) as creatures;
```

롤백은 스키마만 바꾼다 — **행 데이터를 지우는 구문은 하나도 없다.**
