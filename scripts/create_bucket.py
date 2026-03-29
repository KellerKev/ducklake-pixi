"""
scripts/create_bucket.py

Idempotent S3 bucket creation via boto3.
Works for both MinIO (local dev) and Hetzner Object Storage (prod).

Called by: pixi run bucket-create  /  pixi run local-up  /  pixi run prod-up
Requires env vars from .env.local or .env.prod to be sourced first.
"""

import os
import sys
import time
import boto3
from botocore.exceptions import ClientError, EndpointResolutionError

# ── Config from environment ────────────────────────────────────────────────────
endpoint    = os.environ["S3_ENDPOINT"]
access_key  = os.environ["S3_ACCESS_KEY_ID"]
secret_key  = os.environ["S3_SECRET_ACCESS_KEY"]
bucket      = os.environ["S3_BUCKET"]
region      = os.environ.get("S3_REGION", "us-east-1")
use_ssl     = os.environ.get("S3_USE_SSL", "true").lower() != "false"

# Normalize endpoint — boto3 needs a full URL
if not endpoint.startswith("http"):
    protocol = "https" if use_ssl else "http"
    endpoint_url = f"{protocol}://{endpoint}"
else:
    endpoint_url = endpoint

# ── Wait for endpoint to be reachable (useful for local-up race condition) ────
def wait_for_endpoint(url: str, retries: int = 10, delay: float = 1.0) -> bool:
    import urllib.request
    health = url.rstrip("/") + "/minio/health/live"
    for i in range(retries):
        try:
            urllib.request.urlopen(health, timeout=2)
            return True
        except Exception:
            if i < retries - 1:
                print(f"  Waiting for S3 endpoint... ({i+1}/{retries})", flush=True)
                time.sleep(delay)
    return False

if not use_ssl:
    print(f"Waiting for local S3 at {endpoint_url}...")
    if not wait_for_endpoint(endpoint_url):
        print("ERROR: S3 endpoint not reachable. Is MinIO running? (pixi run minio-start)")
        sys.exit(1)

# ── Create bucket ──────────────────────────────────────────────────────────────
s3 = boto3.client(
    "s3",
    endpoint_url=endpoint_url,
    aws_access_key_id=access_key,
    aws_secret_access_key=secret_key,
    region_name=region,
)

try:
    if region == "us-east-1":
        s3.create_bucket(Bucket=bucket)
    else:
        s3.create_bucket(
            Bucket=bucket,
            CreateBucketConfiguration={"LocationConstraint": region},
        )
    print(f"Bucket created: s3://{bucket}/")
except ClientError as e:
    code = e.response["Error"]["Code"]
    if code in ("BucketAlreadyOwnedByYou", "BucketAlreadyExists"):
        print(f"Bucket exists:  s3://{bucket}/")
    else:
        print(f"ERROR: {e}")
        sys.exit(1)
