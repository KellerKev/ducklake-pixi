#!/usr/bin/env bash

echo '=== PostgreSQL ==='
pg_ctl -D .ducklake/pgdata status 2>/dev/null || echo 'not running'
echo ''
echo '=== MinIO ==='
if [ -f .ducklake/minio.pid ] && kill -0 "$(cat .ducklake/minio.pid)" 2>/dev/null; then
    echo "running (PID $(cat .ducklake/minio.pid))"
else
    echo 'not running'
fi
