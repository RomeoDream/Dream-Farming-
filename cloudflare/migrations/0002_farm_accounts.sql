-- Farm-owner authentication foundation; apply once in Cloudflare D1 Console.
CREATE TABLE IF NOT EXISTS farm_accounts (
 farm_id TEXT PRIMARY KEY REFERENCES farms(id),
 login_name TEXT NOT NULL UNIQUE COLLATE NOCASE,
 password_salt TEXT NOT NULL,
 password_hash TEXT NOT NULL,
 password_iterations INTEGER NOT NULL DEFAULT 310000,
 created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS farm_sessions (
 token_hash TEXT PRIMARY KEY,
 farm_id TEXT NOT NULL REFERENCES farms(id),
 expires_at INTEGER NOT NULL,
 created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_farm_sessions_expiry ON farm_sessions(expires_at);
