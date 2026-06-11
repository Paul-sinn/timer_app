-- Phase 3 step 1: 신규 가입 시 profiles 자동 생성 + profiles.updated_at 자동 갱신

-- 신규 auth.users insert → public.profiles 행 자동 생성.
-- security definer: auth 스키마 트리거가 public에 쓰려면 필요. search_path 고정 + 정규화 참조로 안전화.
create function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, display_name)
  values (
    new.id,
    coalesce(
      new.raw_user_meta_data ->> 'name',
      new.raw_user_meta_data ->> 'full_name'
    )
  );
  return new;
end;
$$;

-- 보안 체크리스트: public의 SECURITY DEFINER 함수는 모든 롤이 호출 가능 → 명시적 revoke.
-- 트리거 실행(테이블 소유자 권한)에는 영향 없음.
revoke execute on function public.handle_new_user() from public, anon, authenticated;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- profiles.updated_at 자동 갱신 (security invoker: 권한 상승 불필요).
create function public.set_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();
