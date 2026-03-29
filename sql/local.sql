-- ─────────────────────────────────────────────────────────────────────────────
-- DuckLake — local dev (MinIO + PostgreSQL on localhost)
-- Run via:  pixi run local:shell
-- ─────────────────────────────────────────────────────────────────────────────

INSTALL ducklake;
INSTALL postgres;
INSTALL httpfs;

-- Local MinIO S3 credentials
CREATE OR REPLACE SECRET local_s3 (
    TYPE       s3,
    KEY_ID     'minioadmin',
    SECRET     'minioadmin',
    ENDPOINT   'localhost:9000',
    URL_STYLE  'path',
    USE_SSL    false,
    REGION     'us-east-1'      -- MinIO requires a region string; value is ignored
);

-- Local PostgreSQL (trust auth, no password needed)
CREATE OR REPLACE SECRET local_pg (
    TYPE     postgres,
    HOST     'localhost',
    PORT     5433,
    DATABASE 'ducklake_catalog',
    USER     'ducklake',
    PASSWORD ''
);

-- Attach the DuckLake catalog
-- The empty string tells DuckDB to use the postgres secret above
ATTACH 'ducklake:postgres:' AS lake (
    DATA_PATH 's3://ducklake/data/'
);

USE lake;

.print '✓ Connected to local DuckLake (MinIO + PostgreSQL)'
.print '  Catalog : localhost:5433/ducklake_catalog'
.print '  Storage : s3://ducklake/data/ (MinIO :9000)'
.print ''
.print 'Quick test:'
.print '  CREATE TABLE test AS SELECT 42 AS answer;'
.print '  FROM test;'
.print '  DROP TABLE test;'
