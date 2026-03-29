-- sql/create_reader.sql
-- Creates the ducklake_reader PostgreSQL role and grants SELECT-only access
-- to the DuckLake catalog tables.
--
-- Run via: pixi run guard-pg-setup
-- Requires: READER_PG_PASSWORD env var, connected as ducklake admin user

-- ── Create role (idempotent) ───────────────────────────────────────────────────
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'ducklake_reader') THEN
    EXECUTE format('CREATE USER ducklake_reader WITH PASSWORD %L',
                   current_setting('guard.reader_password'));
    RAISE NOTICE 'Created role ducklake_reader';
  ELSE
    EXECUTE format('ALTER USER ducklake_reader WITH PASSWORD %L',
                   current_setting('guard.reader_password'));
    RAISE NOTICE 'ducklake_reader exists — password refreshed';
  END IF;
END $$;

-- ── Catalog-level grants ───────────────────────────────────────────────────────
GRANT CONNECT ON DATABASE ducklake_catalog TO ducklake_reader;
GRANT USAGE ON SCHEMA public TO ducklake_reader;

-- SELECT on all current DuckLake catalog tables
GRANT SELECT ON ALL TABLES IN SCHEMA public TO ducklake_reader;

-- Ensure new catalog tables added by future DuckLake migrations are also readable
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT SELECT ON TABLES TO ducklake_reader;

-- Explicitly block write paths (belt-and-suspenders; SELECT-only role can't write anyway)
REVOKE INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public FROM ducklake_reader;
