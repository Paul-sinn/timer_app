-- Phase 4: 출시 전 스키마 보강(파괴적 변경 없이 컬럼만 추가 — 모두 nullable/default).
-- 향후 필드 변경은 금지(이름변경/삭제/타입변경). 추가는 옵셔널/기본값으로만. (CLAUDE.md 데이터 정책)

-- focus_sessions: 어느 캐릭터와 한 세션인지 + 모드. companion_id로 진화 단계를 정확히 귀속.
alter table public.focus_sessions add column if not exists companion_id uuid;   -- FK 없음(동기화 순서 무관, idempotent 유지)
alter table public.focus_sessions add column if not exists mode text;            -- 'free' | 'pomodoro'

-- hatched_creatures: 기기간 동기화 충돌 해결·정렬용.
alter table public.hatched_creatures add column if not exists updated_at timestamptz;

-- profiles: 설정 동기화(jsonb로 미래 컬럼 churn 방지) + 유료 플랜 게이트.
alter table public.profiles add column if not exists settings jsonb not null default '{}'::jsonb;
alter table public.profiles add column if not exists is_premium boolean not null default false;

-- 진화 단계 귀속 조회 인덱스(companion_id 기준 완료 세션 집계).
create index if not exists focus_sessions_companion_idx
  on public.focus_sessions (companion_id);
