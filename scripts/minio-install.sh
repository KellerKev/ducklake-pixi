#!/usr/bin/env bash
set -euo pipefail

mkdir -p .ducklake/bin
if [ -f .ducklake/bin/minio ]; then
    echo 'minio already installed'
    exit 0
fi

OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')
echo "Downloading MinIO for ${OS}/${ARCH}..."
curl -sSfL "https://dl.min.io/server/minio/release/${OS}-${ARCH}/minio" \
    -o .ducklake/bin/minio && chmod +x .ducklake/bin/minio
echo "MinIO installed -> .ducklake/bin/minio"
