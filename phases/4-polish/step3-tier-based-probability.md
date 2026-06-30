# Phase 4 step3 — 확률표 등급기반 2단계 추첨 리팩터

날짜: 2026-06-30 · 빌드 성공 · CreatureSpeciesTests 통과.

## 배경
앞으로 몬스터를 계속 추가할 예정. 기존엔 `CreatureSpecies.weight`가 종별 고정값 + **전역 합 100** 강제라,
새 종 추가 때마다 전체 재배분 → 기존 종 확률이 다 흔들림. "100% 안에서 다 해결" 필요.

## 변경 — 확률을 "종"이 아니라 "등급 티어"에 고정
- `Rarity.tierWeight`(신규): Common 80 / Uncommon 10 / Rare 8 / Legendary 2 = **합 100(불변)**.
- `CreatureSpecies.weight`: 의미 변경 → **같은 등급 내 상대 가중치**(전역 합100 불필요).
- `CreatureSpecies.roll`: 2단계 — ① `rollRarity`(tierWeight 가중) → ② `weightedPick`(등급 내 종 가중). 둘 다 주입형 RNG.
- 실제 출현% = `rarity.tierWeight%` × (weight / 같은 등급 weight 합).

## 효과
- **새 종 추가 = 그 등급 내부만 재분배.** 다른 등급 확률 불변. 예) Common에 새 몬스터 추가해도 Legendary 1%는 그대로.
- 현재 7종 실제 확률 **정확히 보존**(닭55·슬라임25·공룡10·검은고양이5·황금병아리3·백호1·피닉스1).
- 가챠 표준 구조 → 추후 픽업/천장 얹기 쉬움.

## 테스트
- `weightsSumTo100` → `rarityTierWeightsSumTo100`(등급 합100).
- `rollDistributionMatchesWeights`: 기대값을 `effectiveProbability(species)`로 교체. 200k 추첨 분포 일치 통과.

## 미래(메모만, 미구현) — 유료 플랜 번들
- **30분 타이머 옵션**: 기본은 60분 고정(무지성 콜렉트 방지). 유료에서 30분 해금 → 콜렉트 위주 유저용.
- **리롤**: 최종진화한 종을 '새 알 받기'로 다시 받아 재집중 시 같은 종 또 나오면 리롤.
- 위 둘 + 종별 단계 진화 아트 = 유료/콘텐츠 확장 묶음.
