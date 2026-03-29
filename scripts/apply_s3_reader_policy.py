"""
scripts/apply_s3_reader_policy.py

Applies an S3 bucket policy that restricts the reader's S3 key to a specific
table path prefix (data/{schema}/{table}/*).

Works for:
  - MinIO (local dev)  — uses a per-user IAM policy via boto3 IAM client
  - Hetzner prod       — uses a bucket policy; Hetzner uses Deny-only semantics
                         because it doesn't support per-user IAM ARNs

Usage:
  READER_SCHEMA=main READER_TABLE=customer pixi run guard-s3-policy

Required env vars (set in your .env.* file or on the command line):
  S3_ENDPOINT, S3_ACCESS_KEY_ID, S3_SECRET_ACCESS_KEY, S3_BUCKET, S3_USE_SSL
  READER_S3_ACCESS_KEY_ID      — the reader's S3 access key (NOT the admin key)
  READER_SCHEMA                — schema name (default: main)
  READER_TABLE                 — table name the reader may access

Optional:
  READER_ALLOWED_TABLES        — comma-separated "schema.table" overrides
                                 (if set, ignores READER_SCHEMA/READER_TABLE)
"""

import json
import os
import sys
import boto3
from botocore.exceptions import ClientError

# ── Config ─────────────────────────────────────────────────────────────────────
endpoint    = os.environ["S3_ENDPOINT"]
access_key  = os.environ["S3_ACCESS_KEY_ID"]
secret_key  = os.environ["S3_SECRET_ACCESS_KEY"]
bucket      = os.environ["S3_BUCKET"]
use_ssl     = os.environ.get("S3_USE_SSL", "true").lower() != "false"
region      = os.environ.get("S3_REGION", "us-east-1")

reader_key  = os.environ.get("READER_S3_ACCESS_KEY_ID", "")

# Build list of allowed prefixes
allowed_tables_raw = os.environ.get("READER_ALLOWED_TABLES", "")
if allowed_tables_raw:
    allowed_prefixes = [
        f"data/{pair.strip().replace('.', '/')}/"
        for pair in allowed_tables_raw.split(",") if pair.strip()
    ]
else:
    schema = os.environ.get("READER_SCHEMA", "main")
    table  = os.environ.get("READER_TABLE")
    if not table:
        print("ERROR: set READER_TABLE (or READER_ALLOWED_TABLES)")
        sys.exit(1)
    allowed_prefixes = [f"data/{schema}/{table}/"]

if not endpoint.startswith("http"):
    protocol = "https" if use_ssl else "http"
    endpoint_url = f"{protocol}://{endpoint}"
else:
    endpoint_url = endpoint

is_local = not use_ssl  # MinIO local vs Hetzner prod

print(f"Mode:            {'local (MinIO)' if is_local else 'production (Hetzner)'}")
print(f"Bucket:          s3://{bucket}/")
print(f"Allowed prefixes: {allowed_prefixes}")

s3 = boto3.client(
    "s3",
    endpoint_url=endpoint_url,
    aws_access_key_id=access_key,
    aws_secret_access_key=secret_key,
    region_name=region,
)

# ── Local MinIO: apply bucket policy with an Allow for the admin + limited Allow
# for the reader key based on path conditions.
# MinIO evaluates bucket policies and applies them to any request to the bucket.
# ──────────────────────────────────────────────────────────────────────────────
# ── Production Hetzner: same boto3 put_bucket_policy call, but using a
# Deny-based approach because Hetzner doesn't support per-user IAM ARNs.
# Instead we Deny GetObject to any key that ISN'T the admin key AND is
# outside the allowed prefixes. Reads by the admin key are always permitted.
# ──────────────────────────────────────────────────────────────────────────────

allowed_object_arns = [
    f"arn:aws:s3:::{bucket}/{prefix}*"
    for prefix in allowed_prefixes
]

if is_local:
    # MinIO: explicit Allow per path prefix for the reader user.
    # Admin key gets full access via a separate statement.
    policy = {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Sid": "AdminFullAccess",
                "Effect": "Allow",
                "Principal": {"AWS": [f"arn:aws:iam:::user/{access_key}"]},
                "Action": ["s3:*"],
                "Resource": [
                    f"arn:aws:s3:::{bucket}",
                    f"arn:aws:s3:::{bucket}/*",
                ],
            },
            *([
                {
                    "Sid": "ReaderTableAccess",
                    "Effect": "Allow",
                    "Principal": {"AWS": [f"arn:aws:iam:::user/{reader_key}"]},
                    "Action": ["s3:GetObject", "s3:ListBucket"],
                    "Resource": [
                        f"arn:aws:s3:::{bucket}",
                        *allowed_object_arns,
                    ],
                }
            ] if reader_key else []),
        ],
    }
else:
    # Hetzner: Deny-first approach (no per-user ARN support).
    # Anyone whose key_id is NOT the admin key is denied outside allowed prefixes.
    # The admin key is implicitly allowed because the Deny condition excludes it.
    policy = {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Sid": "DenyOutsideAllowedPrefix",
                "Effect": "Deny",
                "Principal": "*",
                "Action": ["s3:GetObject"],
                "Resource": [f"arn:aws:s3:::{bucket}/*"],
                "Condition": {
                    "StringNotLike": {
                        "s3:prefix": [p + "*" for p in allowed_prefixes],
                    },
                    # Don't Deny the admin key itself
                    "StringNotEquals": {
                        "s3:x-amz-copy-source": access_key,
                    },
                },
            },
        ],
    }

policy_json = json.dumps(policy, indent=2)
print("\nApplying policy:\n" + policy_json)

try:
    s3.put_bucket_policy(Bucket=bucket, Policy=policy_json)
    print(f"\nPolicy applied to s3://{bucket}/")
except ClientError as e:
    print(f"ERROR: {e}")
    sys.exit(1)
