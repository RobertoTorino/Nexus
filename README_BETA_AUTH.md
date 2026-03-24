# Nexus Beta Auth Contract (AHK/EXE)

## Goal
Do **not** ship provider API keys in the client. Nexus only talks to your backend and receives short-lived access tokens.

## Client Settings (`nexus.ini` / `[SETTINGS]`)
- `BetaAuthEnabled=0|1`
- `BetaAuthBaseUrl=https://your-api.example.com`
- `BetaAuthInviteCode=<invite-code-for-beta-user>`
- `BetaAuthHealthCheckOnStartup=0|1`
- `BetaAuthHealthEndpoint=/nexus/health`

## Device Identity
- Nexus generates/stores a persistent GUID in INI section `[BETA]` key `DeviceId`.
- This is sent with auth calls for revocation/rate-limit decisions.

## Endpoints
### `POST /auth/register`
Request JSON:
```json
{
  "invite_code": "ABC-123",
  "device_id": "guid",
  "client": "nexus-ahk",
  "platform": "windows",
  "app_version": "1.0.00"
}
```
Success response JSON (200):
```json
{
  "data": {
    "access_token": "...",
    "refresh_token": "...",
    "expires_in": 1800,
    "token_type": "Bearer"
  }
}
```

### `POST /auth/refresh`
Request JSON:
```json
{
  "refresh_token": "...",
  "device_id": "guid"
}
```
Success response JSON (200):
```json
{
  "data": {
    "access_token": "...",
    "refresh_token": "...",
    "expires_in": 1800,
    "token_type": "Bearer"
  }
}
```

### `POST /auth/revoke`
Request JSON:
```json
{
  "refresh_token": "...",
  "device_id": "guid"
}
```
Success: `200` or `204`.

## Token Storage in Nexus
- Tokens are encrypted with Windows DPAPI in `data/auth/beta_tokens.bin`.
- Storage is user-context protected (works for current Windows account).

## AHK Client Helpers
- `AuthManager.RequestAuthorized(method, endpoint, payload := "")`
  - Auto-ensures session.
  - Sends `Authorization: Bearer <access_token>`.
  - If HTTP `401`, automatically attempts refresh once and retries.
- `AuthManager.GetAuthorizedJson(endpoint, method := "GET", payload := "")`
  - Convenience wrapper that returns parsed `data` object (`Map`) or empty `Map()` on failure.
- `AuthManager.RunStartupHealthCheck()`
  - Optional deferred call from startup to verify backend reachability and token validity.

## Backend Security Baseline
- Keep provider/master API keys on server only.
- Validate invite codes and device state server-side.
- Issue short-lived access tokens (15-30 min).
- Support token revocation and emergency kill switch.
- Apply per-device and per-IP rate limits.
- Log auth events and anomalous spikes.

## Cloudflare Workers Blueprint (Recommended)

### Why this option
- Very low ops overhead for beta.
- Built-in global edge + HTTPS.
- Good secrets management (`wrangler secret`).

### Stack
- Runtime: Cloudflare Workers (TypeScript)
- DB: D1 (SQLite)
- Optional cache/rate-limit counters: KV
- Secrets: `ACCESS_JWT_SECRET`, `REFRESH_HASH_SECRET`, provider API keys

### D1 schema (minimum)
```sql
CREATE TABLE IF NOT EXISTS beta_invites (
                                          code TEXT PRIMARY KEY,
                                          max_uses INTEGER NOT NULL DEFAULT 1,
                                          use_count INTEGER NOT NULL DEFAULT 0,
                                          expires_at INTEGER,
                                          revoked INTEGER NOT NULL DEFAULT 0,
                                          created_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS beta_devices (
                                          device_id TEXT PRIMARY KEY,
                                          invite_code TEXT NOT NULL,
                                          platform TEXT,
                                          client TEXT,
                                          app_version TEXT,
                                          revoked INTEGER NOT NULL DEFAULT 0,
                                          created_at INTEGER NOT NULL,
                                          updated_at INTEGER NOT NULL,
                                          FOREIGN KEY(invite_code) REFERENCES beta_invites(code)
);

CREATE TABLE IF NOT EXISTS refresh_tokens (
                                            id TEXT PRIMARY KEY,
                                            device_id TEXT NOT NULL,
                                            token_hash TEXT NOT NULL,
                                            expires_at INTEGER NOT NULL,
                                            revoked INTEGER NOT NULL DEFAULT 0,
                                            replaced_by TEXT,
                                            created_at INTEGER NOT NULL,
                                            FOREIGN KEY(device_id) REFERENCES beta_devices(device_id)
);

CREATE INDEX IF NOT EXISTS idx_refresh_device ON refresh_tokens(device_id);
CREATE INDEX IF NOT EXISTS idx_refresh_hash ON refresh_tokens(token_hash);
```

### Token model
- Access token: JWT, signed with `ACCESS_JWT_SECRET`, TTL `900-1800` seconds.
- Refresh token: random 32+ bytes (base64url), **store only hash** in DB.
- Rotate refresh token on every `/auth/refresh`.
- Revoke old token immediately when rotating.

### Endpoint behavior (server)

#### `POST /auth/register`
1. Validate JSON + required fields.
2. Validate invite (`revoked=0`, `expires_at`, `use_count < max_uses`).
3. Upsert `beta_devices` by `device_id`.
4. Mint access + refresh token pair.
5. Store hashed refresh token.
6. Increment invite `use_count` (if policy requires per-registration count).
7. Return contract response:
```json
{"data":{"access_token":"...","refresh_token":"...","expires_in":1800,"token_type":"Bearer"}}
```

#### `POST /auth/refresh`
1. Validate JSON.
2. Hash incoming refresh token and find active row.
3. Verify `device_id` matches and token not expired/revoked.
4. Verify device not revoked.
5. Revoke current row + insert replacement refresh token row.
6. Mint new access token.
7. Return same `data` shape as register.

#### `POST /auth/revoke`
1. Validate JSON.
2. Hash incoming token, mark token row revoked.
3. Optionally revoke device (policy toggle).
4. Return `204` (or `200`).

#### `GET /nexus/health`
- Require bearer access token.
- Verify JWT signature and expiry.
- Return `200` + small JSON body (`{"data":{"ok":true}}`).

### Access token claims (recommended)
```json
{
  "sub": "device_id",
  "scope": "nexus.beta",
  "invite": "ABC-123",
  "iat": 1700000000,
  "exp": 1700001800,
  "iss": "nexus-auth"
}
```

### Rate limiting (practical beta defaults)
- `/auth/register`: 5/min per IP, 20/day per invite code.
- `/auth/refresh`: 30/min per device.
- `/nexus/*`: per device + per IP bucket.
- Add temporary block list for abusive IPs/device IDs.

### Required validations
- Strict JSON schema checks (length caps and allowed charset for `device_id`).
- Reject unknown content-types.
- Enforce HTTPS only.
- Constant-time hash comparison for refresh token hashes.

### Worker route protection pattern
- Public: `/auth/register`, `/auth/refresh`, `/auth/revoke`.
- Protected: `/nexus/*` (middleware verifies bearer JWT first).

### `wrangler` setup checklist
1. `npm create cloudflare@latest nexus-auth-api`
2. Add D1 binding in `wrangler.toml`:
```toml
[[d1_databases]]
binding = "DB"
database_name = "nexus-beta"
database_id = "<generated-id>"
```
3. Apply schema:
   `wrangler d1 execute nexus-beta --file=./schema.sql`
4. Set secrets:
   `wrangler secret put ACCESS_JWT_SECRET`
   `wrangler secret put REFRESH_HASH_SECRET`
   `wrangler secret put PROVIDER_API_KEY`
5. Deploy:
   `wrangler deploy`

### Operational best practices
- Keep short access TTL; never issue non-expiring tokens.
- Rotate `ACCESS_JWT_SECRET` on schedule (support dual-key verify during rotation if needed).
- Keep audit log entries for register/refresh/revoke + failures.
- Add one-click global kill switch (`revoked=1` for all devices) for incident response.

### Nexus-side mapping
- `BetaAuthBaseUrl` -> Worker URL or custom domain (`https://api.yourdomain.com`).
- `BetaAuthHealthEndpoint` -> `/nexus/health`.
- Existing `AuthManager` already matches response envelope and refresh-on-401 behavior.

## Complete command runbook (copy/paste)

Run from PowerShell.

### 0) Go to backend folder
```powershell
Set-Location C:/_repositories/Nexus/backend/nexus-auth-worker
```

### 1) Prereqs + login
```powershell
node -v
npm -v
npm install
./node_modules/.bin/wrangler.cmd login
./node_modules/.bin/wrangler.cmd whoami
```

### 2) Create remote D1 (first time only)
```powershell
./node_modules/.bin/wrangler.cmd d1 create nexus-beta
```

Copy the printed `database_id` into `backend/nexus-auth-worker/wrangler.toml` (`[[d1_databases]]` block).

### 3) Apply schema to remote D1
```powershell
./node_modules/.bin/wrangler.cmd d1 execute nexus-beta --remote --file ./schema.sql
```

### 4) Set required secrets
```powershell
./node_modules/.bin/wrangler.cmd secret put ACCESS_JWT_SECRET
./node_modules/.bin/wrangler.cmd secret put REFRESH_HASH_SECRET
```

### 5) Deploy worker
```powershell
./node_modules/.bin/wrangler.cmd deploy
```

Copy the deployed URL and set in `nexus.ini`:
- `BetaAuthBaseUrl=https://<your-worker-or-domain>`
- `BetaAuthEnabled=1`

### 6) Seed first invite(s) on remote
```powershell
./seed-invites.ps1 -DatabaseName nexus-beta -Remote -Count 1 -MaxUses 1 -ExpiresInDays 30 -Prefix BETA
```

### 7) Verify exports/ops on remote
```powershell
./export-active-invites.ps1 -DatabaseName nexus-beta -Remote
./ops-daily.ps1 -DatabaseName nexus-beta -Remote
```

### 8) Register scheduled daily ops (remote by default)
```powershell
./register-ops-daily-task.ps1 -TaskName NexusAuthDailyOps -DailyTime 09:00 -DatabaseName nexus-beta -RunNow
Get-ScheduledTaskInfo -TaskName NexusAuthDailyOps | Select-Object LastRunTime,LastTaskResult,NextRunTime
```

### 9) Emergency lockout commands (incident)
```powershell
./emergency-rotate-and-revoke.ps1 -DatabaseName nexus-beta -Remote -DeployAfter
./emergency-rotate-and-revoke.ps1 -DatabaseName nexus-beta -Remote -RevokeAllDevices -RevokeAllInvites -DeployAfter
```

## Scenario: invite a beta tester

### Operator flow
1. Generate one invite code for the tester:
```powershell
Set-Location C:/_repositories/Nexus/backend/nexus-auth-worker
./seed-invites.ps1 -DatabaseName nexus-beta -Remote -Count 1 -MaxUses 1 -ExpiresInDays 14 -Prefix WAVE1
```
2. Copy the produced code (example: `WAVE1-ABCD1234`).
3. Send tester package + config instructions.

### Tester instructions
1. Install/run Nexus build.
2. In `nexus.ini` set:
- `BetaAuthEnabled=1`
- `BetaAuthBaseUrl=https://<your-worker-or-domain>`
- `BetaAuthInviteCode=<their-code>`
3. Launch Nexus. On first auth, Nexus registers device and stores tokens with DPAPI.

### Operator verification after tester joins
```powershell
Set-Location C:/_repositories/Nexus/backend/nexus-auth-worker
./ops-daily.ps1 -DatabaseName nexus-beta -Remote
./export-active-invites.ps1 -DatabaseName nexus-beta -Remote
```

Expected signals:
- `active_devices` increases (seen in summary JSON).
- Invite use decreases / invite no longer active if `MaxUses=1`.

### Revoke one tester (if needed)
Run global emergency rotation/revocation:
```powershell
Set-Location C:/_repositories/Nexus/backend/nexus-auth-worker
./emergency-rotate-and-revoke.ps1 -DatabaseName nexus-beta -Remote -DeployAfter
```

Then issue replacement invite(s):
```powershell
./seed-invites.ps1 -DatabaseName nexus-beta -Remote -Count 5 -MaxUses 1 -ExpiresInDays 14 -Prefix WAVE2
```

## Cost-safe beta defaults (recommended)

Use these defaults while your tester group is small.

### Policy defaults
- Invite TTL: `7-14` days.
- Invite max uses: `1` for individual invites.
- Access token TTL: `1800` seconds.
- Keep daily scheduled ops at `1` run/day.
- Only run emergency rotation on incidents (not routinely).

### Low-cost invite command patterns
Single disposable self-test invite:
```powershell
Set-Location C:/_repositories/Nexus/backend/nexus-auth-worker
./seed-invites.ps1 -DatabaseName nexus-beta -Remote -Count 1 -MaxUses 1 -ExpiresInDays 7 -Prefix SELFTEST
```

Small batch for controlled wave:
```powershell
Set-Location C:/_repositories/Nexus/backend/nexus-auth-worker
./seed-invites.ps1 -DatabaseName nexus-beta -Remote -Count 10 -MaxUses 1 -ExpiresInDays 14 -Prefix WAVE1
```

### Minimal monitoring cadence
On demand:
```powershell
Set-Location C:/_repositories/Nexus/backend/nexus-auth-worker
./ops-daily.ps1 -DatabaseName nexus-beta -Remote
```

Scheduled once per day (already configured):
```powershell
Get-ScheduledTaskInfo -TaskName NexusAuthDailyOps | Select-Object LastRunTime,LastTaskResult,NextRunTime
```

### Guardrails to avoid surprise usage
- Do not create high `Count` invite batches unless needed.
- Keep `MaxUses=1` unless sharing a code is intentional.
- Expire unused invites quickly (`ExpiresInDays <= 14`).
- Revoke and reissue invites for churned testers instead of raising `MaxUses`.

## Current live setup (this workspace)

Use these values as your baseline in this repo/environment.

- Worker base URL: `https://nexus-auth-worker.pnvdwolf.workers.dev`
- D1 database: `nexus-beta` (remote)
- Scheduled task: `NexusAuthDailyOps` (daily, remote mode)

`nexus.ini` target values (`[SETTINGS]`):
- `BetaAuthEnabled=1`
- `BetaAuthBaseUrl=https://nexus-auth-worker.pnvdwolf.workers.dev`
- `BetaAuthHealthEndpoint=/nexus/health`

## WAVE1 quick start (10 testers)

Run from `C:/_repositories/Nexus/backend/nexus-auth-worker`:

```powershell
Set-Location C:/_repositories/Nexus/backend/nexus-auth-worker

# 1) Create 10 one-time invites, 14-day expiry
./seed-invites.ps1 -DatabaseName nexus-beta -Remote -Count 10 -MaxUses 1 -ExpiresInDays 14 -Prefix WAVE1

# 2) Export active invite list to a dedicated CSV
./export-active-invites.ps1 -DatabaseName nexus-beta -Remote -OutputPath ./exports/wave1-invites.csv

# 3) Verify backend counters
./ops-daily.ps1 -DatabaseName nexus-beta -Remote
```

Share one unique code per tester from `exports/wave1-invites.csv`.

Tester-side `nexus.ini` requirements:
- `BetaAuthEnabled=1`
- `BetaAuthBaseUrl=https://nexus-auth-worker.pnvdwolf.workers.dev`
- `BetaAuthInviteCode=<their-unique-code>`

Expected after successful tester auth:
- `active_devices` increases.
- Invite with `MaxUses=1` is consumed and no longer listed as active.

## Quick troubleshooting

- If terminal says `http://_vscodecontentref_/...` command not found, remove markdown link formatting and run plain command text.
- If status dot is red and backend has no logs, check latest `nexus.log` entries for `AuthManager` warnings.
- If `/auth/register` returns HTTP 500, verify secrets exist:
  `./node_modules/.bin/wrangler.cmd secret list`
