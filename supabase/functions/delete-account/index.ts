// 계정 삭제 + Sign in with Apple 토큰 철회
//
// App Store 계정 삭제 요건: Apple로 로그인한 계정을 삭제하면 Apple REST API로 토큰도 철회해야 한다.
// 철회에는 Apple 개인 키(.p8)로 서명한 client_secret이 필요해서, 키를 앱이 아닌 이 함수(서버)에 둔다.
//
// 흐름
//   1. 요청한 사용자 확인 (Authorization 헤더의 Supabase 세션)
//   2. 앱이 방금 받은 Apple authorizationCode → Apple에서 토큰 교환 → 토큰 철회
//   3. Supabase 계정 삭제 (subscriptions는 on delete cascade로 함께 삭제)
//   Apple 철회가 실패해도 사용자의 삭제 요청은 처리한다. 결과는 appleTokenRevoked로 돌려준다.
//
// 필요한 Secrets (supabase secrets set ...)
//   APPLE_TEAM_ID       Apple Developer 팀 ID
//   APPLE_KEY_ID        Sign in with Apple 키의 Key ID
//   APPLE_PRIVATE_KEY   .p8 파일 내용 전체 (-----BEGIN PRIVATE KEY----- 포함)
//   APPLE_CLIENT_ID     앱 번들 ID (<BUNDLE_ID_PREFIX>.subhelp)
// SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY는 Supabase가 자동으로 넣어준다.

import { createClient } from "npm:@supabase/supabase-js@2";
import { importPKCS8, SignJWT } from "npm:jose@5";

const APPLE_BASE_URL = "https://appleid.apple.com";

type DeleteAccountRequest = { authorizationCode?: unknown };

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return json({ error: "method_not_allowed" }, 405);
  }

  const authorization = req.headers.get("Authorization");
  if (!authorization) {
    return json({ error: "unauthorized" }, 401);
  }

  const supabaseUrl = requireEnv("SUPABASE_URL");
  const userClient = createClient(supabaseUrl, requireEnv("SUPABASE_ANON_KEY"), {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false },
  });
  const { data: userData, error: userError } = await userClient.auth.getUser();
  const user = userData?.user;
  if (userError || !user) {
    return json({ error: "unauthorized" }, 401);
  }

  let body: DeleteAccountRequest = {};
  try {
    body = await req.json();
  } catch {
    // 본문이 없으면 Apple 철회 없이 삭제만 진행
  }
  const authorizationCode = typeof body.authorizationCode === "string" ? body.authorizationCode : null;

  let appleTokenRevoked = false;
  if (authorizationCode) {
    try {
      await revokeAppleToken(authorizationCode);
      appleTokenRevoked = true;
    } catch (error) {
      console.error("Apple token revocation failed:", error instanceof Error ? error.message : error);
    }
  }

  const admin = createClient(supabaseUrl, requireEnv("SUPABASE_SERVICE_ROLE_KEY"), {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { error: deleteError } = await admin.auth.admin.deleteUser(user.id);
  if (deleteError) {
    console.error("User deletion failed:", deleteError.message);
    return json({ error: "delete_failed" }, 500);
  }

  return json({ deleted: true, appleTokenRevoked });
});

/// Apple REST API용 client_secret (ES256 JWT, 5분 유효)
async function makeClientSecret(clientId: string): Promise<string> {
  const privateKey = requireEnv("APPLE_PRIVATE_KEY").replace(/\\n/g, "\n");
  const key = await importPKCS8(privateKey, "ES256");
  const now = Math.floor(Date.now() / 1000);
  return await new SignJWT({})
    .setProtectedHeader({ alg: "ES256", kid: requireEnv("APPLE_KEY_ID") })
    .setIssuer(requireEnv("APPLE_TEAM_ID"))
    .setIssuedAt(now)
    .setExpirationTime(now + 300)
    .setAudience(APPLE_BASE_URL)
    .setSubject(clientId)
    .sign(key);
}

/// authorizationCode → 토큰 교환 → 토큰 철회
async function revokeAppleToken(authorizationCode: string): Promise<void> {
  const clientId = requireEnv("APPLE_CLIENT_ID");
  const clientSecret = await makeClientSecret(clientId);

  const tokenResponse = await postForm(`${APPLE_BASE_URL}/auth/token`, {
    client_id: clientId,
    client_secret: clientSecret,
    code: authorizationCode,
    grant_type: "authorization_code",
  });
  if (!tokenResponse.ok) {
    throw new Error(`token exchange failed (${tokenResponse.status}): ${await tokenResponse.text()}`);
  }
  const tokens = await tokenResponse.json() as { refresh_token?: string; access_token?: string };
  const token = tokens.refresh_token ?? tokens.access_token;
  if (!token) {
    throw new Error("token exchange returned no token");
  }

  const revokeResponse = await postForm(`${APPLE_BASE_URL}/auth/revoke`, {
    client_id: clientId,
    client_secret: clientSecret,
    token,
    token_type_hint: tokens.refresh_token ? "refresh_token" : "access_token",
  });
  if (!revokeResponse.ok) {
    throw new Error(`revoke failed (${revokeResponse.status}): ${await revokeResponse.text()}`);
  }
}

function postForm(url: string, params: Record<string, string>): Promise<Response> {
  return fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams(params),
  });
}

function requireEnv(name: string): string {
  const value = Deno.env.get(name);
  if (!value) {
    throw new Error(`Missing environment variable: ${name}`);
  }
  return value;
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
