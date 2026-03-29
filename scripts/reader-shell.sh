#!/usr/bin/env bash
set -euo pipefail

# Build the ATTACH command for the reader role
ATTACH_CMD="ATTACH 'ducklake:postgres:host=${POSTGRES_HOST} port=${POSTGRES_PORT} dbname=ducklake_catalog user=ducklake_reader password=${READER_PG_PASSWORD}' AS lake (DATA_PATH 's3://${S3_BUCKET}/data/', READ_ONLY); USE lake;"

TMPINIT=$(mktemp).sql
trap 'rm -f "$TMPINIT"' EXIT

# Reader uses its own S3 key
cat > "$TMPINIT" << SQL
INSTALL ducklake;
LOAD ducklake;
INSTALL httpfs;
LOAD httpfs;
INSTALL postgres;
LOAD postgres;

SET s3_endpoint          = '${S3_ENDPOINT}';
SET s3_access_key_id     = '${READER_S3_ACCESS_KEY_ID}';
SET s3_secret_access_key = '${READER_S3_SECRET_ACCESS_KEY}';
SET s3_region            = '${S3_REGION}';
SET s3_url_style         = 'path';
SET s3_use_ssl           = ${S3_USE_SSL:-true};

${ATTACH_CMD}

SELECT 'Connected as ducklake_reader' AS status;
SHOW TABLES;
SQL

exec duckdb -init "$TMPINIT" "$@"
