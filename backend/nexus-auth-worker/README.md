# Nexus Auth Worker (Cloudflare)

Minimal backend for Nexus beta auth flow.

## Fast setup (PowerShell)

From this folder:

`./setup-backend.ps1 -DatabaseName nexus-beta -InviteCode ABC-123 -MaxUses 100`

This script installs dependencies, creates D1, updates `wrangler.toml`, applies schema, and seeds an invite.
You still need to set secrets manually afterward.

## 1) Install

npm install

## 2) Create D1 database

wrangler d1 create nexus-beta

Copy the database_id into wrangler.toml.

## 3) Apply schema

wrangler d1 execute nexus-beta --file=./schema.sql

## 4) Set secrets

wrangler secret put ACCESS_JWT_SECRET
wrangler secret put REFRESH_HASH_SECRET

## 5) Seed at least one invite

Example:

wrangler d1 execute nexus-beta --command "INSERT INTO beta_invites(code,max_uses,use_count,expires_at,revoked,created_at) VALUES('ABC-123',100,0,NULL,0,strftime('%s','now'));"

## 6) Run locally

wrangler dev

## 7) Deploy

wrangler deploy

## Emergency lockout / key rotation

If you suspect token leakage or abuse, run:

`./emergency-rotate-and-revoke.ps1 -DatabaseName nexus-beta -Remote -DeployAfter`

Default behavior:
- Rotates `ACCESS_JWT_SECRET`
- Rotates `REFRESH_HASH_SECRET`
- Revokes all active refresh tokens

Optional stronger lockout:

`./emergency-rotate-and-revoke.ps1 -DatabaseName nexus-beta -Remote -RevokeAllDevices -RevokeAllInvites -DeployAfter`

Use `-DryRun` to preview actions without applying changes.

## Generate replacement invites

After lockout, create fresh invite codes with:

`./seed-invites.ps1 -DatabaseName nexus-beta -Remote -Count 1 -MaxUses 1 -ExpiresInDays 30 -Prefix BETA`

Bulk example:

`./seed-invites.ps1 -DatabaseName nexus-beta -Remote -Count 25 -MaxUses 3 -ExpiresInDays 14 -Prefix WAVE1`

Preview without writing to D1:

`./seed-invites.ps1 -DatabaseName nexus-beta -Remote -Count 5 -DryRun`

## Export active invites to CSV

List all currently active invites and export to CSV:

`./export-active-invites.ps1 -DatabaseName nexus-beta -Remote`

Custom output path example:

`./export-active-invites.ps1 -DatabaseName nexus-beta -Remote -OutputPath ./exports/current-active-invites.csv`

## Daily ops wrapper

Run lockout status checks, export active invites, and write a JSON summary:

`./ops-daily.ps1 -DatabaseName nexus-beta -Remote`

Skip invite CSV export (summary only):

`./ops-daily.ps1 -DatabaseName nexus-beta -Remote -SkipExport`

Custom artifact paths:

`./ops-daily.ps1 -DatabaseName nexus-beta -Remote -ExportPath ./exports/daily-invites.csv -SummaryPath ./exports/daily-summary.json`

## Schedule daily run on Windows

Register a daily scheduled task (default 09:00):

`./register-ops-daily-task.ps1 -TaskName NexusAuthDailyOps -DailyTime 09:00 -DatabaseName nexus-beta`

By default, scheduled runs use remote D1. Use `-Local` only for local dev state.

Register and run immediately once:

`./register-ops-daily-task.ps1 -TaskName NexusAuthDailyOps -DailyTime 09:00 -DatabaseName nexus-beta -RunNow`

Remove the scheduled task:

`./register-ops-daily-task.ps1 -TaskName NexusAuthDailyOps -Remove`

## Contract compatibility

This Worker returns the response envelope expected by Nexus AuthManager:

- POST /auth/register
- POST /auth/refresh
- POST /auth/revoke
- GET /nexus/health

and JSON:

{
  "data": {
    "access_token": "...",
    "refresh_token": "...",
    "expires_in": 1800,
    "token_type": "Bearer"
  }
}
