#!/usr/bin/env bash
set -euo pipefail

# Build the ATTACH command with env vars (DuckDB ATTACH doesn't support expressions)
ATTACH_CMD="ATTACH 'ducklake:postgres:host=${POSTGRES_HOST} port=${POSTGRES_PORT} dbname=ducklake_catalog user=ducklake password=${POSTGRES_PASSWORD}' AS lake (DATA_PATH 's3://${S3_BUCKET}/data/'); USE lake;"

# Create a temporary init file that sources init.sql then attaches
TMPINIT=$(mktemp).sql
trap 'rm -f "$TMPINIT"' EXIT

cat init.sql > "$TMPINIT"
echo "" >> "$TMPINIT"
echo "-- ── Attach DuckLake (generated from env vars) ──" >> "$TMPINIT"
echo "$ATTACH_CMD" >> "$TMPINIT"
echo "" >> "$TMPINIT"
cat >> "$TMPINIT" << 'SQL'
-- Confirm
SELECT 'DuckLake ready' AS status,
       current_setting('s3_endpoint') AS s3,
       current_database() AS db;
SQL

exec duckdb -init "$TMPINIT" "$@"
