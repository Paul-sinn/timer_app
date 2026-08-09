// delete-account — 로그인 사용자가 자신의 계정을 영구 삭제(App Store 심사 요건 5.1.1(v)).
//
// 흐름: 호출자의 JWT로 본인 user.id를 확인 → service_role로 auth 유저 삭제.
// public.profiles/focus_sessions/hatched_creatures는 FK on delete cascade로 함께 삭제된다.
// SUPABASE_URL / SUPABASE_ANON_KEY / SUPABASE_SERVICE_ROLE_KEY는 Edge Function 기본 시크릿.
//
// 보안 정책:
//  - CORS는 기본 거부. 네이티브 iOS 앱(URLSession)은 Origin 헤더를 보내지 않으므로 영향 없다.
//    웹 클라이언트를 붙일 때만 ALLOWED_ORIGINS 시크릿(쉼표 구분)에 오리진을 명시적으로 등록한다.
//    (이전엔 `*`였다 — service_role을 쥔 파괴적 엔드포인트에 와일드카드는 불필요하게 넓다.)
//  - POST만 허용. 파괴적 동작을 GET으로 트리거할 수 있으면 안 된다.

import { createClient } from "jsr:@supabase/supabase-js@2";

/// 명시적으로 허용된 브라우저 오리진(쉼표 구분). 미설정 = 브라우저 호출 전면 차단.
const ALLOWED_ORIGINS = (Deno.env.get("ALLOWED_ORIGINS") ?? "")
  .split(",")
  .map((o) => o.trim())
  .filter((o) => o.length > 0);

/// 요청 Origin이 허용 목록에 있을 때만 그 값을 반향한다. 와일드카드는 쓰지 않는다.
function corsHeaders(req: Request): Record<string, string> {
  const base: Record<string, string> = {
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    Vary: "Origin",
  };
  const origin = req.headers.get("Origin");
  if (origin && ALLOWED_ORIGINS.includes(origin)) {
    base["Access-Control-Allow-Origin"] = origin;
  }
  return base;
}

function json(req: Request, body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders(req), "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders(req) });
  }

  // 계정 삭제는 파괴적이다 — POST 외의 메서드로는 트리거되지 않게 한다.
  if (req.method !== "POST") {
    return json(req, { error: "Method not allowed" }, 405);
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return json(req, { error: "Missing authorization header" }, 401);

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

    // 1) 호출자 신원 확인(전달된 access token으로).
    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: { user }, error: userErr } = await userClient.auth.getUser();
    if (userErr || !user) return json(req, { error: "Invalid or expired session" }, 401);

    // 2) service_role로 본인 계정 삭제(데이터는 cascade로 함께 삭제).
    const admin = createClient(supabaseUrl, serviceKey);
    const { error: delErr } = await admin.auth.admin.deleteUser(user.id);
    if (delErr) {
      console.error("deleteUser failed", { userId: user.id, message: delErr.message });
      return json(req, { error: "Failed to delete account" }, 500);
    }

    return json(req, { success: true }, 200);
  } catch (e) {
    // 내부 예외 메시지를 클라이언트에 그대로 노출하지 않는다(구현 세부 유출 방지).
    console.error("delete-account unhandled", e);
    return json(req, { error: "Internal error" }, 500);
  }
});
