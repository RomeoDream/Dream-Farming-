-- Add identities without renaming/deleting existing farms, accounts or inventory.
-- Existing aliases stay internal until an administrator supplies actual SL UUIDs.
ALTER TABLE farms ADD COLUMN sl_uuid TEXT;
ALTER TABLE farms ADD COLUMN owner_uuid TEXT;
CREATE UNIQUE INDEX idx_farm_sl_uuid ON farms(sl_uuid) WHERE sl_uuid IS NOT NULL;
CREATE INDEX idx_farm_owner_uuid ON farms(owner_uuid);
ALTER TABLE farm_objects ADD COLUMN sl_uuid TEXT;
CREATE UNIQUE INDEX idx_object_sl_uuid ON farm_objects(sl_uuid) WHERE sl_uuid IS NOT NULL;
