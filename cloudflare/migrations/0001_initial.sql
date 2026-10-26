CREATE TABLE IF NOT EXISTS farms (
 id TEXT PRIMARY KEY,
 name TEXT NOT NULL,
 created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS farm_objects (
 id TEXT PRIMARY KEY,
 farm_id TEXT NOT NULL REFERENCES farms(id),
 credential_hash TEXT NOT NULL,
 revoked INTEGER NOT NULL DEFAULT 0,
 revision INTEGER NOT NULL DEFAULT 0,
 state_json TEXT NOT NULL DEFAULT '{}',
 updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_farm_objects_farm ON farm_objects(farm_id);
CREATE TABLE IF NOT EXISTS inventory (
 farm_id TEXT NOT NULL REFERENCES farms(id),
 material TEXT NOT NULL,
 quantity INTEGER NOT NULL DEFAULT 0 CHECK(quantity >= 0),
 PRIMARY KEY(farm_id, material)
);
CREATE TABLE IF NOT EXISTS transfer_receipts (
 id TEXT PRIMARY KEY,
 farm_id TEXT NOT NULL REFERENCES farms(id),
 material TEXT NOT NULL,
 quantity INTEGER NOT NULL CHECK(quantity > 0),
 source_object TEXT NOT NULL,
 destination_object TEXT NOT NULL,
 status TEXT NOT NULL CHECK(status IN ('reserved','committed','cancelled')),
 expires_at INTEGER NOT NULL,
 created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_transfer_farm ON transfer_receipts(farm_id, status);
