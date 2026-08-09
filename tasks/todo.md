# 하이프 대비 — 보안 하드닝 + 동기화 스케일 (2026-08-09)

## 배경
"사용자가 몰리면 뭐가 취약한가" 감사에서 나온 항목을 정리해 실행한다.
감사 범위: 코드 · 리포 · 라이브 Supabase(`qvaqiuabsplcwfedoklu`) · 빌드 설정.

라이브 규모(작업 시작 시점): auth.users 1 / focus_sessions 102 / hatched_creatures 41 / DB 11MB.
**지금이 스키마 하드닝을 하기에 가장 싼 시점**이라는 게 이번 작업의 전제.

문제없음이 확인된 것: 리포 내 시크릿 0 · `print`/`NSLog` 0건 · 세션은 Keychain(기본) ·
ATS 무효화 없음 · entitlements는 applesignin 하나 · PrivacyInfo 정확 · Package.resolved 커밋됨 ·
Apple nonce 구현 정석(SecRandom + 거부 샘플링, 편향 없음) · RLS 3테이블 4 cmd 완비, anon 정책 0.

---

## 사용자 확인 필요 (내 도구로 접근 불가)
- [ ] **Google 프로바이더** — Auth → Providers. 앱에 Google 로그인이 실제로 없다
      (SDK 미설치 / client ID 플레이스홀더 / identities는 apple 1건).
      서버 스위치가 켜져 있으면 아무도 안 쓰는 인증 경로가 열린 것.
      `Skip nonce check` + 빈 `Authorized Client IDs` 조합이면 타 앱 발급 토큰으로 로그인 가능.
      → **안 쓸 거면 끄는 게 정답**
- [ ] **Max rows** — Project Settings → API. 기본 1000.
      이 값 모르면 부하 테스트가 거짓 합격을 낸다(잘린 응답 = 빨라 보임).
- [ ] Rate Limits — Auth → Rate Limits. (급하지 않음)
- [ ] **프로덕션 DB 마이그레이션 적용 승인** — 무료 플랜이라 브랜치가 없어 모든 DB 변경 = 즉시 프로덕션
- [ ] 워킹 트리 정리 방침 (untracked 113 / modified 61 / deleted 24)

---

## A. 드리프트 해소 — 완료(적용 대기)
- [x] 누락 마이그레이션 2개 파일 복원 (라이브 기록과 md5 일치 검증)
      `20260805060257_create_sync_tables_...` / `20260805060504_drop_redundant_own_policies`
      → **적용 대상 아님.** 이미 `schema_migrations`에 있음. 리포↔프로덕션 동기화 목적
- [x] `20260809100000_drop_duplicate_indexes.sql` 작성
      두 인덱스 정의 동일 확인 · PK/unique 미연결 확인 · 둘 다 `idx_scan=0`
- [ ] 적용 (위험도 낮음, 롤백 2줄)
- [ ] **별건 드리프트**: 리포 `20260630120000_add_companion_mode_premium.sql` vs
      라이브 버전 `20260630221527`. 파일명 리네임 또는 `migration repair` 필요 — 판단 보류

## B. 보안 하드닝 — 4종 전부 프로덕션 적용 완료
- [x] 권한 회수 — anon **0권한**, authenticated는 CRUD 4종만(TRUNCATE/REFERENCES/TRIGGER 제거).
      `alter default privileges`로 신규 테이블 기본값도 좁힘
- [x] `handle_new_user` 예외 안전화 — 중첩 EXCEPTION + `on conflict do nothing` + `raise warning`
- [x] 값 상한 제약 10개 + 미래 timestamp 거부 트리거(PT400)
      CHECK가 `now()`를 못 쓰는 문제는 CHECK(절대경계) + 트리거(now()+1일) 분담으로 해결
- [x] 유저당 쓰기 쿼터 5000행/일 — 카운터 테이블 + 문 단위 트리거(PT429 → HTTP 429)

### 리허설 (격리 스키마 `_rehearsal`, 16항목 전부 PASS → 적용 후 삭제)
브랜치도 CLI도 없어서 라이브 DB 안에 격리 스키마를 만들어 복제 테이블로 실증했다.
가장 중요했던 세 가지 — 전부 추측이 아니라 실행으로 확인:
- **재-upsert가 쿼터를 소모하지 않는다** (`ON CONFLICT DO UPDATE`의 AFTER INSERT 전이 테이블엔
  실제 삽입 행만 들어옴). 5행 재푸시 후 카운터 5 유지, 기존5+신규3 → 8.
  → `syncOnLogin()` 멱등성 보존 확인
- **초과 시 문 전체 롤백**(카운터 증가분 포함) → counter 8→8 / rows 8→8. 재시도 이중 증가 없음
- **트리거 함수 EXECUTE 회수가 쓰기를 막지 않는다** — authenticated로 직접 INSERT해서 확인.
  틀렸으면 전체 쓰기 장애였다. 권한 검사는 CREATE TRIGGER 시점에만 이뤄진다
- RLS 켜진 카운터 테이블에 SECURITY DEFINER 함수가 쓸 수 있음(소유자 RLS 우회) + authenticated는
  카운터 직접 접근 불가(42501)
- 프로덕션 실물 스모크: 실제 유저 id로 insert→검증→delete. 세션 102 원복, 미래시각·값상한 거부 확인
- [x] `delete-account` 함수: CORS 와일드카드 제거(기본 거부 + 허용목록) · POST 강제 · 내부 예외 메시지 비노출
      → 로컬 수정만. 배포 대기
- [x] `START_TAB` 훅을 `#if DEBUG`로 격리 (`CREATURE_GALLERY`와 정책 일치)

## C. 동기화 스케일 — C1 완료 / C2 작업 중
- [x] **C1 페이지네이션** — `.range()` 500행 페이지 + `id` tiebreaker + id 중복제거 +
      `select` 컬럼 명시 + push 청크 분할 + `returning: .minimal`.
      외부 시그니처 4개 불변(C2와 충돌 회피). 순수 로직 22 테스트
- [ ] **C2 실패 표면화 + 지수 백오프/지터** (`try?` 6곳)
- [ ] C3 킬스위치 — DB가 녹아도 동기화를 끌 방법이 앱 업데이트(심사 1~2일)뿐. 보류

## D. 검증 — 완료
- [x] `xcodebuild build` → **BUILD SUCCEEDED**, error 0 (에이전트 전원 종료 후 직렬 1회)
      경고 7건 중 신규 파일 관련 2건은 `SyncModels.toResult()/toCreature()`의 **기존** 경고
      (nonisolated struct → MainActor init 호출). 이번 변경과 무관
- [x] `xcodebuild test -only-testing:EggtimerTests` → **168 passed / 0 failed / 0 skipped**
      (기존 102 + 신규 66: 페이지네이션 22 + 재시도·분류 44)
- [x] `get_advisors` 재실행
      - duplicate_index WARN 2건 **해소됨**
      - 신규 INFO: `write_quota_daily` RLS 켜짐+정책 0 → **의도된 설계**(어떤 API 롤도 접근 불가)
      - leaked password WARN → 이메일 프로바이더 끄면 무의미해짐
      - unused_index INFO 3건 → 유저 1명이라 아직 쿼리가 안 탄 것. 조치 불필요

## 미결 (사람 결정 필요)
- [ ] **이메일 프로바이더 끄기** — 앱에 이메일 로그인 UI 없음, 비밀번호 보유 유저 0명 확인.
      Apple 릴레이 주소는 Apple 프로바이더 소관이라 영향 없음
- [ ] **Anonymous sign-ins 켜져 있는지 확인** — 앱이 안 쓴다. 켜져 있으면 끌 것
- [ ] **Rate limit 상향** — 회원가입/로그인 30건/5분은 하이프 때 제일 먼저 터진다.
      IP별이라도 한국 통신사 NAT로 수천 명이 IP를 공유한다. 정확한 값은 부하 테스트 후
- [ ] **`delete-account` 엣지 함수 배포** — CORS 좁히기·POST 강제·예외 메시지 비노출.
      로컬 수정만 해둠. 실제 JWT로 검증할 수 없어 배포는 보류 — 계정 삭제는 심사 요건이라
      깨지면 곤란하다. 배포 후 앱에서 1회 수동 확인 권장
- [ ] 워킹 트리 정리 / 커밋 방침
- [ ] 마이그레이션 파일명 드리프트: 리포 `20260630120000` vs 라이브 `20260630221527`

## E. 부하 테스트 (후속, 별도 트랙)
감사는 "코드가 취약해 보이는가"만 답한다. "몇 명까지 버티나"는 측정해야 안다.
단, 부하 테스트는 A·B 항목을 **대체하지 않는다** — 정적 권한·로직 결함·악의적 1인 시나리오는
부하로 안 잡힌다. 병렬 트랙으로 간다.
- [ ] Pro 업그레이드 (백업/PITR + 브랜치). **부하 테스트의 선행조건**이지 결론이 아님.
      Free는 공유 컴퓨트라 재현 가능한 숫자가 안 나온다
- [ ] 시딩 스크립트 (유저 N × 기록 M) — Admin API로 유저 생성. OIDC는 스크립트 불가.
      이게 부하 테스트 본체보다 일이 많다
- [ ] k6 시나리오 50→100→250→500→1000, 유저당 0/200/1000건
- [ ] 측정 후 컴퓨트 사이즈 결정 (사이징은 측정 전엔 근거 없음 — 이 지적은 타당)

합격 기준: p95 < 1s / 5xx·429 < 0.5% / CPU < 70% / 데이터 누락 0 / 서버 다운 시 로컬 정상.
안전 수용량 = 통과 최대치의 절반.

---

## 실행 규칙 (이번 작업)
- 에이전트는 `xcodebuild` 금지. 빌드는 메인이 마지막에 직렬 1회
- 에이전트는 `apply_migration`·쓰기 SQL 금지. 적용은 사람 승인 후 메인이 직렬로
- 파일 소유권 분리: C1 = `SyncService`/`SyncModels`, C2 = `SyncCoordinator`
- SourceKit이 "Cannot find type"을 무더기로 뱉는 건 인덱스 문제. 빌드로 판정할 것
