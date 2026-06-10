# 컬렉션 도감 + 확률 부화 + 진화

## 목표
- images/charactor 동물들로 컬렉션 채우기
- 미발견 종은 검은 실루엣 + 가운데 "?" (픽셀 톤)
- 확률표대로 가중 랜덤 부화 (합 100%)
- 빨간 토종닭은 여러 표정 중 랜덤
- 백호·피닉스는 20분 뒤 진화

## 확률표
| 등급 | 생명체 | 확률 |
|---|---|---|
| Common | 빨간 토종닭 | 55% |
| Common | 슬라임 | 25% |
| Uncommon | 아기 공룡 | 10% |
| Rare | 검은 고양이 | 5% |
| Rare | 황금 병아리 | 3% |
| Legendary | 백호 | 1% |
| Legendary | 피닉스 | 1% |

## 작업
- [x] 배경 제거 스크립트(scripts/make_creature_assets.py) — 14개 PNG → 투명 trim 에셋
- [x] Rarity: epic→uncommon 재정의(Common/Uncommon/Rare/Legendary), 색/점/정렬
- [x] CreatureSpecies(신규): 7종 카탈로그 + 가중 랜덤 roll() + 변형 풀 + 진화 이미지
- [x] Creature: species 기반 + 진화(20분) + hatch 팩토리
- [x] CreatureImage: 실제 픽셀 에셋 렌더 + 실루엣 모드(검은 윤곽 + "?")
- [x] CollectionView: 전체 7종 나열, 발견/미발견(실루엣) n/7
- [x] CollectionStore(신규): 탭 공유 도감, hatch() 추가
- [x] HomeView: 알 탭 → 부화 → HatchResultSheet, 스토어 연결
- [x] RootView: 공유 스토어 주입(홈 부화 → 컬렉션 반영)
- [x] 테스트: 가중치 합/분포/진화/변형 (CreatureSpeciesTests)
- [x] 빌드 성공
- [x] 테스트 통과 (8/8, 분포 20만 회 검증 포함)
- [x] 시뮬레이터 검수: 컬렉션 5/7 + 실루엣 + 백호 진화 / 홈 알 렌더

## 에셋 매핑
- 닭(Common, 랜덤 6종): Chicken1, ChickenAngry, ChickenAnnoyed, ChickenBro, ChickenSleepy, ChickenSmart
- Slime / Dino / BlackCat / GoldChick
- WhiteTiger → WhiteTigerEvolved (진화)
- Phoenix → PhoenixEvolved (진화)

## 리뷰
- 시뮬레이터 컬렉션 탭: "발견한 친구들 5/7", 발견 5종 픽셀 카드, 미발견 2종(황금 병아리·피닉스)은 검은 실루엣 + 가운데 "?". 백호는 골드 테두리 + 진화 이미지로 표시됨.
- 확률 로직은 CreatureSpecies.roll()에 집약(단일 진실 소스). 가중치 합 100 검증, 20만 회 분포 테스트 통과.
- 빨간 토종닭은 6종 표정 풀에서 랜덤(부화 시점 고정). 백호·피닉스만 20분 뒤 진화.
- 부화 트리거는 Phase 0 더미라 "알 탭"으로 시험(주석에 Phase 2 자동 호출 명시). 부화 → CollectionStore에 추가 → 컬렉션 반영.

## 후속(미포함)
- 실제 타이머 완료 시 자동 부화(Phase 2) 연결
- 영속화(SwiftData) — 현재는 앱 재시작 시 컬렉션 초기화
