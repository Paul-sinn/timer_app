//
//  SupabaseService.swift
//  Eggtimer
//
//  Supabase 클라이언트 단일 진입점(Phase 3-2). 모든 원격 통신은 이 Services 레이어를 경유한다
//  (ARCHITECTURE: View에서 Supabase 직접 호출 금지). 행 접근은 RLS가 통제하므로 클라는 본인 데이터만 read/write.
//

import Foundation
import Supabase

/// Supabase 프로젝트 연결 설정.
/// publishable 키는 클라이언트 노출용으로 설계된 공개 키(service_role/secret 아님) — 소스에 둬도 안전하며 RLS가 실제 접근을 통제한다.
enum SupabaseConfig {
    static let url = URL(string: "https://qvaqiuabsplcwfedoklu.supabase.co")!
    static let publishableKey = "sb_publishable_pMgHElqXKGInvytE53OJ7A_nXdKMXiO"
}

/// 앱 전역에서 공유하는 SupabaseClient 래퍼. 네트워크 레이어이므로 MainActor에 묶지 않는다(nonisolated).
nonisolated final class SupabaseService {
    static let shared = SupabaseService()

    let client: SupabaseClient

    private init() {
        client = SupabaseClient(
            supabaseURL: SupabaseConfig.url,
            supabaseKey: SupabaseConfig.publishableKey
        )
    }
}
