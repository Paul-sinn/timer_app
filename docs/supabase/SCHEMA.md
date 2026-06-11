# Supabase 스키마 (Phase 3 step 1)

원격 프로젝트의 `public` 클라우드 스키마. 로컬 SwiftData 모델을 1:1 미러링해 향후 동기화를 위한 기반을 만든다.

- **접근 모델**: iOS 클라이언트가 Supabase에 **직접** read/write. 행 접근은 RLS로 통제(본인 행만). FastAPI 경유(ADR-004)는 AI 도입 시점까지 보류.
- **PK 전략**: `id`는 **클라이언트가 생성한 UUID**(로컬 SwiftData `id`와 동일). 동기화를 idempotent upsert로 구현 가능.
- 마이그레이션: `supabase/migrations/` (원격 적용 + git 버전관리).

## 테이블

### `profiles` — `auth.users` 1:1 확장
| 컬럼 | 타입 | 비고 |
|------|------|------|
| `id` | uuid PK | `auth.users(id)` FK, on delete cascade |
| `display_name` | text | nullable. 가입 시 `raw_user_meta_data`의 `name`/`full_name`에서 채움 |
| `created_at` | timestamptz | default now() |
| `updated_at` | timestamptz | default now(), 트리거로 자동 갱신 |

### `focus_sessions` — `FocusSessionRecord` 미러
| 컬럼 | 타입 | 비고 |
|------|------|------|
| `id` | uuid PK | 로컬 세션 id |
| `user_id` | uuid | `auth.users(id)` FK, on delete cascade |
| `started_at` | timestamptz | |
| `planned_seconds` | int | check ≥ 0 |
| `active_seconds` | int | check ≥ 0 |
| `interruption_count` | int | default 0, check ≥ 0 |
| `distracted` | bool | default false |
| `completed` | bool | default false |
| `created_at` | timestamptz | default now() |

인덱스: `(user_id, started_at desc)`

### `hatched_creatures` — `HatchedCreatureRecord` 미러
| 컬럼 | 타입 | 비고 |
|------|------|------|
| `id` | uuid PK | 로컬 생명체 id |
| `user_id` | uuid | `auth.users(id)` FK, on delete cascade |
| `species` | text | `CreatureSpecies.rawValue` |
| `image_name` | text | 부화 시 확정된 이미지 변형 |
| `hatched_at` | timestamptz | |
| `created_at` | timestamptz | default now() |

인덱스: `(user_id, hatched_at desc)`

> 레어도(`Rarity`)·종 메타데이터는 클라이언트 enum이 단일 소스라 DB 정규화 테이블을 두지 않음(MVP). 종 문자열만 저장.

## RLS
3개 테이블 모두 RLS 활성화. 작업(select/insert/update/delete)별 정책을 `to authenticated` + 소유권 술어로 분리(테이블당 4개, 총 12개).
- profiles: `(select auth.uid()) = id`
- focus_sessions / hatched_creatures: `(select auth.uid()) = user_id`
- update 정책은 `using` + `with check` 둘 다 두어 소유자 재할당 차단.
- `(select auth.uid())` 래핑으로 행마다 재평가 방지(성능). `auth.role()`·`user_metadata` 미사용.
- Data API: `authenticated`에만 GRANT, `anon`은 권한 없음.

## 트리거/함수
- `public.handle_new_user()` — `auth.users` after insert. 신규 가입 시 `profiles` 행 자동 생성. `security definer set search_path=''`, anon/authenticated/public에 execute revoke.
- `public.set_updated_at()` — `profiles` before update. `updated_at = now()`. `security invoker`.

## 다음 step (범위 밖)
- iOS: supabase-swift SDK 추가, Apple/Google 로그인, SwiftData ↔ Supabase 동기화 서비스(upsert)
- Supabase Storage(캐릭터 정식 에셋), 필요 시 FastAPI(ADR-004 갱신)
