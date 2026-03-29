-- ─────────────────────────────────────────────────────────────────────────────
-- DuckLake — production (Hetzner Object Storage + remote PostgreSQL)
-- Run via:  pixi run prod:shell
-- Requires: .env populated (see .env.sample); loaded automatically by Pixi.
-- ─────────────────────────────────────────────────────────────────────────────

INSTALL ducklake;
INSTALL postgres;
INSTALL httpfs;

-- Hetzner Object Storage credentials (from environment)
-- Endpoint example: fsn1.your-objectstorage.com  or  nbg1.your-objectstorage.com
CREATE OR REPLACE SECRET hetzner_s3 (
    TYPE      s3,
    KEY_ID    getenv('S3_ACCESS_KEY_ID'),
    SECRET    getenv('S3_SECRET_ACCESS_KEY'),
    ENDPOINT  getenv('S3_ENDPOINT'),
    REGION    getenv('S3_REGION'),
    URL_STYLE 'path',
    USE_SSL   true
);

-- Remote PostgreSQL catalog credentials (from environment)
CREATE OR REPLACE SECRET hetzner_pg (
    TYPE     postgres,
    HOST     getenv('POSTGRES_HOST'),
    PORT     5432,
    DATABASE 'ducklake_catalog',
    USER     'ducklake',
    PASSWORD getenv('POSTGRES_PASSWORD')
);

-- Attach the DuckLake catalog
ATTACH 'ducklake:postgres:' AS lake (
    DATA_PATH printf('s3://%s/data/', getenv('S3_BUCKET'))
);

USE lake;

.print '✓ Connected to Hetzner DuckLake'
