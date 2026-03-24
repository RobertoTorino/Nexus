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
