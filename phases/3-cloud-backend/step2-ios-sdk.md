# Phase 3 · Step 2 — iOS supabase-swift SDK 연동

**완료:** 2026-06-11

## 목표
iOS 앱에 supabase-swift SDK를 추가하고, 모든 원격 통신의 단일 진입점이 될 SupabaseClient 래퍼를 Services 레이어에 만든다.

## 작업
- `Eggtimer.xcodeproj/project.pbxproj` 수동 편집으로 SPM 의존성 추가
  (objectVersion 77 / FileSystemSynchronized 그룹 → 새 .swift는 자동 인식, SPM만 수동):
  - XCRemoteSwiftPackageReference: `supabase/supabase-swift`, upToNextMajor 2.0.0
  - XCSwiftPackageProductDependency: `Supabase`
  - PBXBuildFile + Frameworks 빌드페이즈 링크 + 타겟 packageProductDependencies + 프로젝트 packageReferences
- 해석: **supabase-swift 2.47.0** + 트랜지티브(swift-crypto 4.5.0, swift-asn1, swift-http-types, swift-clocks, xctest-dynamic-overlay, swift-concurrency-extras). `Package.resolved` 커밋(락파일 핀, 보안 체크리스트).
- `Services/SupabaseService.swift`: `SupabaseConfig`(URL + publishable 키) + `SupabaseService.shared.client`.
  - publishable 키는 클라이언트 노출용 공개 키 → 소스에 둬도 안전, RLS가 실제 접근 통제.

## 검증
- `xcodebuild build ... -destination 'iPhone 17 Pro'` → **BUILD SUCCEEDED**.

## 메모 / 보류
- macOS(Catalyst/sandbox) 빌드 시 `com.apple.security.network.client` 엔타이틀먼트 필요할 수 있음(iOS는 기본 허용). macOS 지원은 후순위라 그때 처리.

## 다음
- Step 3: Auth 서비스 스캐폴딩(세션 상태). 실제 Apple/Google 공급자 설정은 사용자 권한이라 보류.
- Step 4: SwiftData ↔ Supabase 동기화 서비스(upsert) + 매핑 단위 테스트.
