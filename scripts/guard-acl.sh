#!/usr/bin/env bash
set -euo pipefail

# Usage: guard-acl.sh grant|revoke|show [SCHEMA TABLE]
ACTION="${1:-show}"
PG_PORT="${POSTGRES_PORT:-5432}"

case "$ACTION" in
    grant)
        SCHEMA="${SCHEMA:-main}"
        TABLE="${TABLE:?TABLE env var required}"
        psql -h "$POSTGRES_HOST" -p "$PG_PORT" -U ducklake -d ducklake_catalog \
            -c "INSERT INTO ducklake_guard_acl VALUES ('ducklake_reader','${SCHEMA}','${TABLE}') ON CONFLICT DO NOTHING;"
        echo "Granted: ducklake_reader -> ${SCHEMA}.${TABLE}"
        ;;
    revoke)
        SCHEMA="${SCHEMA:-main}"
        TABLE="${TABLE:?TABLE env var required}"
        psql -h "$POSTGRES_HOST" -p "$PG_PORT" -U ducklake -d ducklake_catalog \
            -c "DELETE FROM ducklake_guard_acl WHERE role_name='ducklake_reader' AND schema_name='${SCHEMA}' AND table_name='${TABLE}';"
        echo "Revoked: ducklake_reader -> ${SCHEMA}.${TABLE}"
        ;;
    show)
        psql -h "$POSTGRES_HOST" -p "$PG_PORT" -U ducklake -d ducklake_catalog \
            -c "SELECT role_name, schema_name, table_name FROM ducklake_guard_acl ORDER BY 1,2,3;"
        ;;
    *)
        echo "Usage: guard-acl.sh grant|revoke|show"
        exit 1
        ;;
esac
