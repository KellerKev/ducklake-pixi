#!/usr/bin/env bash
set -euo pipefail

echo 'Setting up ducklake_reader role and RLS...'
psql \
    -h "$POSTGRES_HOST" \
    -p "${POSTGRES_PORT:-5432}" \
    -U ducklake \
    -d ducklake_catalog \
    -v guard.reader_password="$READER_PG_PASSWORD" \
    -f sql/create_reader.sql
psql \
    -h "$POSTGRES_HOST" \
    -p "${POSTGRES_PORT:-5432}" \
    -U ducklake \
    -d ducklake_catalog \
    -f sql/enable_rls.sql
echo 'Guard PG setup complete.'
