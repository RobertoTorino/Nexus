import { jwtVerify, SignJWT } from "jose";

type Env = {
  DB: D1Database;
  ACCESS_JWT_SECRET: string;
  REFRESH_HASH_SECRET: string;
};

type JsonObj = Record<string, unknown>;

const ACCESS_TTL_SECONDS = 1800;
const REFRESH_TTL_SECONDS = 60 * 60 * 24 * 14;

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    try {
      const url = new URL(request.url);
      const path = url.pathname;

      if (request.method === "POST" && path === "/auth/register") {
        return await handleRegister(request, env);
      }
      if (request.method === "POST" && path === "/auth/refresh") {
        return await handleRefresh(request, env);
      }
      if (request.method === "POST" && path === "/auth/revoke") {
        return await handleRevoke(request, env);
      }
      if (request.method === "GET" && path === "/nexus/health") {
        const auth = await requireAccessAuth(request, env);
        if (!auth.ok) return auth.response;
        return json(200, { data: { ok: true, now: nowUnix() } });
      }

      if (path.startsWith("/nexus/")) {
        const auth = await requireAccessAuth(request, env);
        if (!auth.ok) return auth.response;
        return json(404, { error: "Not implemented" });
      }

      return json(404, { error: "Not found" });
    } catch {
      return json(500, { error: "Internal server error" });
    }
  }
};

async function handleRegister(request: Request, env: Env): Promise<Response> {
  const body = await parseJson(request);
  if (!body) return json(400, { error: "Invalid JSON" });

  const inviteCode = safeString(body.invite_code, 128);
  const deviceId = safeString(body.device_id, 128);
  const client = safeString(body.client, 64);
  const platform = safeString(body.platform, 64);
  const appVersion = safeString(body.app_version, 64);

  if (!inviteCode || !deviceId) return json(400, { error: "Missing required fields" });
  if (!isSafeDeviceId(deviceId)) return json(400, { error: "Invalid device_id" });

  const invite = await env.DB.prepare(
    "SELECT code, max_uses, use_count, expires_at, revoked FROM beta_invites WHERE code = ?"
  ).bind(inviteCode).first<Record<string, number | string | null>>();

  if (!invite) return json(401, { error: "Auth failed" });
  if (Number(invite.revoked ?? 0) !== 0) return json(401, { error: "Auth failed" });

  const expiresAt = Number(invite.expires_at ?? 0);
  if (expiresAt > 0 && expiresAt <= nowUnix()) return json(401, { error: "Auth failed" });

  const maxUses = Number(invite.max_uses ?? 0);
  const useCount = Number(invite.use_count ?? 0);
  if (maxUses > 0 && useCount >= maxUses) return json(401, { error: "Auth failed" });

  const now = nowUnix();

  await env.DB.prepare(
    `INSERT INTO beta_devices(device_id, invite_code, platform, client, app_version, revoked, created_at, updated_at)
     VALUES(?, ?, ?, ?, ?, 0, ?, ?)
     ON CONFLICT(device_id) DO UPDATE SET
       invite_code = excluded.invite_code,
       platform = excluded.platform,
       client = excluded.client,
       app_version = excluded.app_version,
       revoked = 0,
       updated_at = excluded.updated_at`
  ).bind(deviceId, inviteCode, platform, client, appVersion, now, now).run();

  await env.DB.prepare(
    "UPDATE beta_invites SET use_count = use_count + 1 WHERE code = ?"
  ).bind(inviteCode).run();

  const tokens = await issueTokenPair(env, deviceId, inviteCode);
  return json(200, { data: tokens });
}

async function handleRefresh(request: Request, env: Env): Promise<Response> {
  const body = await parseJson(request);
  if (!body) return json(400, { error: "Invalid JSON" });

  const refreshToken = safeString(body.refresh_token, 1024);
  const deviceId = safeString(body.device_id, 128);

  if (!refreshToken || !deviceId) return json(400, { error: "Missing required fields" });

  const tokenHash = await hashRefresh(refreshToken, env.REFRESH_HASH_SECRET);
  const row = await env.DB.prepare(
    `SELECT id, device_id, expires_at, revoked
     FROM refresh_tokens
     WHERE token_hash = ?
     LIMIT 1`
  ).bind(tokenHash).first<Record<string, string | number>>();

  if (!row) return json(401, { error: "Auth failed" });
  if (String(row.device_id) !== deviceId) return json(401, { error: "Auth failed" });
  if (Number(row.revoked ?? 0) !== 0) return json(401, { error: "Auth failed" });
  if (Number(row.expires_at ?? 0) <= nowUnix()) return json(401, { error: "Auth failed" });

  const device = await env.DB.prepare(
    "SELECT invite_code, revoked FROM beta_devices WHERE device_id = ?"
  ).bind(deviceId).first<Record<string, string | number>>();

  if (!device) return json(401, { error: "Auth failed" });
  if (Number(device.revoked ?? 0) !== 0) return json(401, { error: "Auth failed" });

  const inviteCode = String(device.invite_code);

  const tokens = await issueTokenPair(env, deviceId, inviteCode, String(row.id));
  return json(200, { data: tokens });
}

async function handleRevoke(request: Request, env: Env): Promise<Response> {
  const body = await parseJson(request);
  if (!body) return json(400, { error: "Invalid JSON" });

  const refreshToken = safeString(body.refresh_token, 1024);
  const deviceId = safeString(body.device_id, 128);

  if (!refreshToken || !deviceId) return json(400, { error: "Missing required fields" });

  const tokenHash = await hashRefresh(refreshToken, env.REFRESH_HASH_SECRET);
  await env.DB.prepare(
    "UPDATE refresh_tokens SET revoked = 1 WHERE token_hash = ? AND device_id = ?"
  ).bind(tokenHash, deviceId).run();

  return new Response(null, { status: 204 });
}

async function issueTokenPair(
  env: Env,
  deviceId: string,
  inviteCode: string,
  oldRefreshId?: string
): Promise<{ access_token: string; refresh_token: string; expires_in: number; token_type: string }> {
  const now = nowUnix();
  const accessExp = now + ACCESS_TTL_SECONDS;

  const accessToken = await new SignJWT({
    scope: "nexus.beta",
    invite: inviteCode
  })
    .setProtectedHeader({ alg: "HS256", typ: "JWT" })
    .setIssuedAt(now)
    .setIssuer("nexus-auth")
    .setSubject(deviceId)
    .setExpirationTime(accessExp)
    .sign(toUtf8(env.ACCESS_JWT_SECRET));

  const refreshToken = makeOpaqueToken();
  const refreshHash = await hashRefresh(refreshToken, env.REFRESH_HASH_SECRET);
  const refreshId = crypto.randomUUID();
  const refreshExp = now + REFRESH_TTL_SECONDS;

  if (oldRefreshId) {
    await env.DB.prepare(
      "UPDATE refresh_tokens SET revoked = 1, replaced_by = ? WHERE id = ?"
    ).bind(refreshId, oldRefreshId).run();
  }

  await env.DB.prepare(
    `INSERT INTO refresh_tokens(id, device_id, token_hash, expires_at, revoked, replaced_by, created_at)
     VALUES(?, ?, ?, ?, 0, NULL, ?)`
  ).bind(refreshId, deviceId, refreshHash, refreshExp, now).run();

  return {
    access_token: accessToken,
    refresh_token: refreshToken,
    expires_in: ACCESS_TTL_SECONDS,
    token_type: "Bearer"
  };
}

async function requireAccessAuth(request: Request, env: Env): Promise<{ ok: true } | { ok: false; response: Response }> {
  const authHeader = request.headers.get("Authorization") || "";
  const parts = authHeader.split(" ");
  if (parts.length !== 2 || parts[0] !== "Bearer" || !parts[1]) {
    return { ok: false, response: json(401, { error: "Unauthorized" }) };
  }

  try {
    await jwtVerify(parts[1], toUtf8(env.ACCESS_JWT_SECRET), {
      issuer: "nexus-auth"
    });
    return { ok: true };
  } catch {
    return { ok: false, response: json(401, { error: "Unauthorized" }) };
  }
}

function json(status: number, body: JsonObj): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "cache-control": "no-store"
    }
  });
}

async function parseJson(request: Request): Promise<JsonObj | null> {
  const ct = request.headers.get("content-type") || "";
  if (!ct.toLowerCase().includes("application/json")) return null;

  try {
    const parsed = await request.json<unknown>();
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) return null;
    return parsed as JsonObj;
  } catch {
    return null;
  }
}

function safeString(value: unknown, maxLen: number): string {
  if (typeof value !== "string") return "";
  const v = value.trim();
  if (!v || v.length > maxLen) return "";
  return v;
}

function isSafeDeviceId(deviceId: string): boolean {
  if (deviceId.length < 8 || deviceId.length > 128) return false;
  return /^[a-zA-Z0-9._:-]+$/.test(deviceId);
}

function nowUnix(): number {
  return Math.floor(Date.now() / 1000);
}

function toUtf8(input: string): Uint8Array {
  return new TextEncoder().encode(input);
}

function makeOpaqueToken(): string {
  const bytes = new Uint8Array(32);
  crypto.getRandomValues(bytes);
  return toBase64Url(bytes);
}

function toBase64Url(bytes: Uint8Array): string {
  let binary = "";
  for (let i = 0; i < bytes.length; i++) binary += String.fromCharCode(bytes[i]);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}

async function hashRefresh(token: string, secret: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    toUtf8(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );

  const sig = await crypto.subtle.sign("HMAC", key, toUtf8(token));
  return toBase64Url(new Uint8Array(sig));
}
