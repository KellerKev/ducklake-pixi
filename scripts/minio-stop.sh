#!/usr/bin/env bash

if [ -f .ducklake/minio.pid ]; then
    kill "$(cat .ducklake/minio.pid)" 2>/dev/null && echo 'MinIO stopped'
    rm -f .ducklake/minio.pid
else
    echo 'MinIO not running'
fi
