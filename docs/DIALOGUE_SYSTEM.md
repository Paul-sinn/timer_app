# 캐릭터 대사 시스템 (dialoguesystem.md 구현)

알·생명체가 사용자 행동에 반응해 살아있는 느낌을 주는 대사 시스템. 톤: 웃기고 약간 비꼬지만 동기부여. 알은 의심꾼 → 존중 → 자부심으로 진화.

## 모델 (`Features/Dialogue/DialogueLine.swift`)
- `DialogueSpeaker`: `.egg` | `.creature(CreaturePersonality)`
- `CreaturePersonality`: redChicken/sleepyChicken/nerdChicken/gymChicken/angryChicken/whiteTiger/phoenix/generic
- `DialogueTrigger`: `.idle`, `.sessionStart`, `.focusMilestone(minutes:)`, `.appReturn(ReturnBucket)`, `.streak(days:)`, `.greeting`
- `ReturnBucket`: within30s / upTo3min / upTo10min / over10min (Interruption 임계값 0–30·180·600초와 동일)
- `DialogueLine`: id·text·speaker·trigger·weight·cooldown

## 카탈로그 (`DialogueCatalog.swift`)
스펙의 영어·풍자 라인을 정확히 수록.
- **알**: idle(보강) + Session Start + 5/10/15/30/45/60분 + 복귀 4버킷 + 스트릭 3/7/30/100
- **생명체**: 7성격 풀(스펙 그대로) + generic(스펙 미정의 종 공용)
- 현지화/AI 확장 대비해 본문을 콘텐츠로 분리.

## 성격 매핑 (`CreatureSpecies.personality(imageName:)`)
닭 표정 변형 → 성격: Chicken1/ChickenAnnoyed→red, ChickenSleepy→sleepy, ChickenSmart→nerd, ChickenBro→gym, ChickenAngry→angry. whiteTiger/phoenix→각자. slime/dino/blackCat/goldChick→generic. `Creature.personality`로 노출.

## 선택 엔진 (`DialogueManager`)
트리거+화자 필터 → 최근표시 제외(링버퍼) → 줄별 쿨다운 → 가중 랜덤. 전역 쿨다운은 ambient한 `.idle`에만 적용(맥락 대사는 항상 통과). 주입형 RNG·시계로 결정적 테스트.

## 연결 (`HomeView` / `SessionManager`)
- 시작: 새 세션(activeSecondsLive==0)에 스트릭 임계 도달 시 `.streak`, 아니면 `.sessionStart`. resume엔 미발화.
- 경과: `activeSecondsLive` 관찰 → 5/15/.../60분 1회씩 `.focusMilestone`.
- 복귀: `scenePhase .active` → `SessionManager.lastAwaySeconds`로 `.appReturn(버킷)`.
- 부화: 태어난 생명체가 `.greeting, speaker: .creature(personality)`로 인사.
- idle: 홈 대기 시 `.idle`.

## 테스트
- `DialogueTests`: 트리거/화자 필터·비반복·쿨다운·맥락 쿨다운 우회·후보없음 안전.
- `DialogueCatalogTests`: 모든 마일스톤/버킷/스트릭/성격 풀 존재, 스펙 라인 표본 포함, id 유일, 성격 매핑, 버킷 경계.
- 32 케이스 통과(빌드+테스트).

## 향후 (스펙의 확장 포인트)
- 현지화(영어 본문 → 다국어), AI 생성 대사, 레어도별 풀 세분화, 성격이 이후 대사 생성에 영향.
