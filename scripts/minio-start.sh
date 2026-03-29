#!/usr/bin/env bash
set -euo pipefail

mkdir -p .ducklake/s3data

if [ -f .ducklake/minio.pid ] && kill -0 "$(cat .ducklake/minio.pid)" 2>/dev/null; then
    echo 'MinIO already running'
    exit 0
fi

MINIO_ROOT_USER="${S3_ACCESS_KEY_ID}" \
MINIO_ROOT_PASSWORD="${S3_SECRET_ACCESS_KEY}" \
    nohup .ducklake/bin/minio server .ducklake/s3data \
        --address         "127.0.0.1:${MINIO_API_PORT:-9000}" \
        --console-address "127.0.0.1:${MINIO_CONSOLE_PORT:-9001}" \
        --quiet > .ducklake/minio.log 2>&1 &
echo $! > .ducklake/minio.pid
sleep 2
echo "MinIO API:     http://127.0.0.1:${MINIO_API_PORT:-9000}"
echo "MinIO Console: http://127.0.0.1:${MINIO_CONSOLE_PORT:-9001}"
