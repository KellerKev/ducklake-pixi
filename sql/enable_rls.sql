-- sql/enable_rls.sql
-- Enables Row Level Security on the DuckLake catalog so that ducklake_reader
-- can only see tables explicitly listed in ducklake_guard_acl.
--
-- How it works:
--   ducklake_guard_acl   — an ACL table you manage: (role, schema, table)
--   RLS policy on ducklake_table   — filters via a JOIN to that ACL table
--   Superuser/owner      — bypasses RLS automatically (Postgres default)
--
-- Run via: pixi run guard-pg-setup
-- Run as : the ducklake owner/superuser

-- ── 1. ACL table ──────────────────────────────────────────────────────────────
-- Stores which tables each Postgres role may see.
-- Managed by you (or a future admin UI). Rows here are the source of truth.
CREATE TABLE IF NOT EXISTS ducklake_guard_acl (
    role_name   text NOT NULL,
    schema_name text NOT NULL,
    table_name  text NOT NULL,
    PRIMARY KEY (role_name, schema_name, table_name)
);

-- Reader can read its own ACL entries (needed for the policy to work)
GRANT SELECT ON ducklake_guard_acl TO ducklake_reader;

-- ── 2. Enable RLS on the primary table catalog ─────────────────────────────────
-- ducklake_table is the source of all table metadata. Hiding rows here prevents
-- the DuckLake extension from even enumerating hidden tables.
ALTER TABLE ducklake_table ENABLE ROW LEVEL SECURITY;

-- Drop existing policy if re-running
DROP POLICY IF EXISTS guard_reader_tables ON ducklake_table;

-- Policy: reader only sees tables present in their ACL
CREATE POLICY guard_reader_tables ON ducklake_table
    FOR SELECT
    TO ducklake_reader
    USING (
        EXISTS (
            SELECT 1
            FROM  ducklake_schema   s
            JOIN  ducklake_guard_acl acl
              ON  acl.schema_name = s.schema_name
             AND  acl.table_name  = ducklake_table.table_name
             AND  acl.role_name   = current_user
            WHERE s.schema_id = ducklake_table.schema_id
        )
    );

-- ── 3. Cascade RLS to dependent catalog tables ─────────────────────────────────
-- These tables reference table_id; a reader with direct PG access could bypass
-- the DuckLake layer and query them. RLS here blocks that.

ALTER TABLE ducklake_column          ENABLE ROW LEVEL SECURITY;
ALTER TABLE ducklake_data_file       ENABLE ROW LEVEL SECURITY;
ALTER TABLE ducklake_table_stats     ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS guard_reader_columns    ON ducklake_column;
DROP POLICY IF EXISTS guard_reader_data_files ON ducklake_data_file;
DROP POLICY IF EXISTS guard_reader_stats      ON ducklake_table_stats;

-- Shared predicate: table_id must be visible via the guarded ducklake_table
CREATE POLICY guard_reader_columns ON ducklake_column
    FOR SELECT TO ducklake_reader
    USING (table_id IN (
        SELECT t.table_id FROM ducklake_table t
        JOIN   ducklake_schema s ON s.schema_id = t.schema_id
        JOIN   ducklake_guard_acl acl
          ON   acl.schema_name = s.schema_name
         AND   acl.table_name  = t.table_name
         AND   acl.role_name   = current_user
    ));

CREATE POLICY guard_reader_data_files ON ducklake_data_file
    FOR SELECT TO ducklake_reader
    USING (table_id IN (
        SELECT t.table_id FROM ducklake_table t
        JOIN   ducklake_schema s ON s.schema_id = t.schema_id
        JOIN   ducklake_guard_acl acl
          ON   acl.schema_name = s.schema_name
         AND   acl.table_name  = t.table_name
         AND   acl.role_name   = current_user
    ));

CREATE POLICY guard_reader_stats ON ducklake_table_stats
    FOR SELECT TO ducklake_reader
    USING (table_id IN (
        SELECT t.table_id FROM ducklake_table t
        JOIN   ducklake_schema s ON s.schema_id = t.schema_id
        JOIN   ducklake_guard_acl acl
          ON   acl.schema_name = s.schema_name
         AND   acl.table_name  = t.table_name
         AND   acl.role_name   = current_user
    ));

-- ── Usage ─────────────────────────────────────────────────────────────────────
-- Grant reader access to a specific table:
--
--   INSERT INTO ducklake_guard_acl VALUES ('ducklake_reader', 'main', 'customer');
--
-- Revoke:
--   DELETE FROM ducklake_guard_acl
--    WHERE role_name='ducklake_reader' AND schema_name='main' AND table_name='customer';
