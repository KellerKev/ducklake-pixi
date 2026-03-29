-- init-reader.sql — DuckDB session for the ducklake_reader role
-- Connects with read-only PostgreSQL credentials and a restricted S3 key.
-- The reader can only see tables in their PostgreSQL RLS ACL and can only
-- GET objects within allowed S3 prefixes.
--
-- Run:  pixi run reader-shell   (calls: duckdb -init init-reader.sql)
-- Env:  source .env.local  (or .env.prod) — reader vars must be set

INSTALL ducklake;
LOAD ducklake;
INSTALL httpfs;
LOAD httpfs;
INSTALL postgres;
LOAD postgres;

-- ── S3: use the reader key (restricted to allowed table prefix(es)) ─────────────
SET s3_endpoint          = getenv('S3_ENDPOINT');
SET s3_access_key_id     = getenv('READER_S3_ACCESS_KEY_ID');
SET s3_secret_access_key = getenv('READER_S3_SECRET_ACCESS_KEY');
SET s3_region            = getenv('S3_REGION');
SET s3_url_style         = 'path';
SET s3_use_ssl           = (getenv('S3_USE_SSL') != 'false');

-- ── Attach DuckLake as read-only using the reader PostgreSQL role ───────────────
ATTACH printf(
    'ducklake:postgres:host=%s port=%s dbname=ducklake_catalog user=ducklake_reader password=%s',
    getenv('POSTGRES_HOST'),
    getenv('POSTGRES_PORT'),
    getenv('READER_PG_PASSWORD')
) AS lake (
    DATA_PATH printf('s3://%s/data/', getenv('S3_BUCKET')),
    READ_ONLY
);

USE lake;

-- Show what this reader is allowed to see
SELECT 'Connected as ducklake_reader' AS status;
SHOW TABLES;
