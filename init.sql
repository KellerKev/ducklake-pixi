-- init.sql — DuckLake initialization
-- Driven entirely by environment variables; cp .env.local .env or .env.prod .env first.
-- Run: pixi run shell   (which calls: duckdb -init init.sql)

-- Extensions (cached after first download)
INSTALL ducklake;
LOAD ducklake;
INSTALL httpfs;
LOAD httpfs;
INSTALL postgres;
LOAD postgres;

-- ── Object Storage config ──────────────────────────────────────────────────────
-- Works for MinIO (local) and Hetzner Object Storage (prod).
-- Both use path-style URLs; the only difference is the endpoint and SSL.

SET s3_endpoint          = getenv('S3_ENDPOINT');
SET s3_access_key_id     = getenv('S3_ACCESS_KEY_ID');
SET s3_secret_access_key = getenv('S3_SECRET_ACCESS_KEY');
SET s3_region            = getenv('S3_REGION');
SET s3_url_style         = 'path';
SET s3_use_ssl           = (getenv('S3_USE_SSL') != 'false');
