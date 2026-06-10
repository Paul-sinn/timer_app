# 아키텍처

## 기술 스택
| 영역 | 선택 |
|------|------|
| 언어 | Swift |
| UI | SwiftUI (Figma에서 디자인 먼저 → Figma MCP로 코드 반영) |
| 개발툴 | Xcode |
| 로컬 저장 | SwiftData |
| 로그인 | Supabase Auth (Apple + Google) |
| 클라우드 DB | Supabase Postgres |
| 파일 저장 | Supabase Storage |
| 백엔드 | FastAPI |
| AI 호출 | FastAPI → OpenAI/Gemini API (현재 미사용, 추후 유료 기능) |
| 아이콘 | Lucide 아이콘 세트 (SwiftUI에서는 SF Symbols / Lucide SVG 에셋으로 사용) |

## 디렉토리 구조
```
FocusEgg/                     # iOS/macOS 앱 (SwiftUI)
├── App/                      # 앱 진입점, 전역 환경 설정
├── Features/
│   ├── Home/                 # 타이머 + 알 화면
│   ├── Collection/           # 부화한 생명체 목록
│   ├── Progress/             # 집중 기록/통계
│   └── MyPage/               # 프로필/설정
├── Components/               # 공용 UI 컴포넌트 (탭바, 버튼, 카드)
├── Models/                   # SwiftData 모델 + 도메인 타입
├── Services/                 # Supabase/FastAPI 래퍼, 화면 유지(idle timer) 등
├── Resources/                # 캐릭터 mock 이미지, 컬러/에셋
└── Mock/                     # 더미 데이터 (1단계 UI 전용)

backend/                      # FastAPI 서버
├── app/
│   ├── routers/              # 엔드포인트 (auth, hatch, history)
│   ├── services/             # Supabase 연동, (추후) AI 호출
│   └── models/               # 요청/응답 스키마
└── tests/
```

## 패턴
- **MVVM 기본**: View(SwiftUI) ↔ ViewModel(상태/로직) ↔ Model(SwiftData/도메인).
- 화면 단위 Feature 폴더링. 공용 요소만 `Components/`로 승격.
- **1단계(프론트 우선)**에서는 ViewModel이 `Mock/`의 더미 데이터를 주입받는다. 실제 Service는 동일 인터페이스로 후순위 교체.
- 외부 통신(Supabase/FastAPI)은 반드시 `Services/` 레이어를 경유. View에서 직접 호출 금지.

## 데이터 흐름
```
[1단계: UI 우선]
사용자 입력 → View → ViewModel → Mock 더미 데이터 → UI 업데이트

[2단계: 기능 구현]
사용자 입력 → View → ViewModel → Service
  ├─ 로컬: SwiftData (세션/컬렉션 캐시)
  └─ 원격: Supabase Auth/Postgres/Storage, FastAPI
            → 응답 → ViewModel → UI 업데이트
```

## 상태 관리
- 화면 로컬 상태: SwiftUI `@State` / `@Observable` ViewModel.
- 영속 상태: SwiftData (타이머 세션 기록, 컬렉션). 원격 동기화는 Supabase.
- 타이머 진행/부화 진행도는 ViewModel이 단일 소스로 관리하여 Home·Progress가 공유.

## 핵심 도메인 규칙
- **부화 진행**: 누적 집중 시간 기준. 기본 15분마다 알의 크랙 단계 1 증가, 목표 누적 시간 도달 시 부화.
- **확률표**: 부화 순간 가중치 테이블로 일반/레어 생명체 결정. 테이블은 데이터로 분리하여 조정 가능.
- **집중 유효성**: iOS에서 화면을 끄지 않고 유지한 시간을 유효 집중 시간으로 기록(화면 꺼짐 방지 기능과 연동).
