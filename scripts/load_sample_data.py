"""
scripts/load_sample_data.py

Loads TPC-H sample data (scale factor 0.01, ~10K rows) into DuckLake.
Uses the DuckDB Python API directly — no separate DuckDB process needed.

Usage: pixi run guard-load-sample
Requires env vars from .env.local or .env.prod to be sourced first.
"""

import os
import duckdb

# ── Config ─────────────────────────────────────────────────────────────────────
pg_host    = os.environ["POSTGRES_HOST"]
pg_port    = os.environ.get("POSTGRES_PORT", "5432")
pg_pass    = os.environ["POSTGRES_PASSWORD"]
s3_ep      = os.environ["S3_ENDPOINT"]
s3_key     = os.environ["S3_ACCESS_KEY_ID"]
s3_secret  = os.environ["S3_SECRET_ACCESS_KEY"]
s3_bucket  = os.environ["S3_BUCKET"]
s3_region  = os.environ.get("S3_REGION", "us-east-1")
use_ssl    = os.environ.get("S3_USE_SSL", "true").lower() != "false"

con = duckdb.connect()

# ── Extensions ─────────────────────────────────────────────────────────────────
for ext in ("ducklake", "httpfs", "postgres", "tpch"):
    con.execute(f"INSTALL {ext}; LOAD {ext};")

# ── S3 config ──────────────────────────────────────────────────────────────────
con.execute(f"SET s3_endpoint          = '{s3_ep}';")
con.execute(f"SET s3_access_key_id     = '{s3_key}';")
con.execute(f"SET s3_secret_access_key = '{s3_secret}';")
con.execute(f"SET s3_region            = '{s3_region}';")
con.execute( "SET s3_url_style         = 'path';")
con.execute(f"SET s3_use_ssl           = {'true' if use_ssl else 'false'};")

# ── Generate TPC-H in memory first (dbgen only works on DuckDB databases) ─────
print("Generating TPC-H data (scale factor 0.01)...")
con.execute("CALL dbgen(sf=0.01);")

# ── Attach DuckLake ────────────────────────────────────────────────────────────
attach_str = (
    f"ducklake:postgres:host={pg_host} port={pg_port} "
    f"dbname=ducklake_catalog user=ducklake password={pg_pass}"
)
con.execute(
    f"ATTACH '{attach_str}' AS lake "
    f"(DATA_PATH 's3://{s3_bucket}/data/');"
)

tpch_tables = [
    "customer", "orders", "lineitem",
    "part", "supplier", "partsupp",
    "nation", "region",
]

con.execute("CREATE SCHEMA IF NOT EXISTS lake.tpch;")

for tbl in tpch_tables:
    print(f"  Loading {tbl}...")
    con.execute(f"CREATE OR REPLACE TABLE lake.tpch.{tbl} AS SELECT * FROM memory.main.{tbl};")
    count = con.execute(f"SELECT count(*) FROM lake.tpch.{tbl};").fetchone()[0]
    print(f"    → {count:,} rows")

print("\nDone. TPC-H tables are in the 'tpch' schema of your DuckLake.")
print("\nTo grant reader access to a table:")
print("  INSERT INTO ducklake_guard_acl VALUES ('ducklake_reader', 'tpch', 'customer');")
