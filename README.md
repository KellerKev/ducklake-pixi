# DuckLake on Hetzner

PostgreSQL catalog + Hetzner Object Storage (S3) + DuckDB query engine.
Everything managed by [Pixi](https://pixi.sh).

## What you get

| Component | Local dev | Production |
|-----------|-----------|------------|
| S3 storage | MinIO (`:9000`) | Hetzner Object Storage |
| Catalog DB | PostgreSQL (`:5433`) | PostgreSQL on any host |
| Query engine | DuckDB CLI | DuckDB CLI |
| Access control | RLS + S3 bucket policy | RLS + S3 bucket policy |

Cost estimate for production: **< €10/month** (cx33 VPS ~€5.50 + Object Storage ~€3.50/TB).

---

## Prerequisites

- [Pixi](https://pixi.sh/latest/) — `curl -fsSL https://pixi.sh/install.sh | bash`
- A Hetzner account (for production only)

Everything else — DuckDB, PostgreSQL, MinIO — is installed by Pixi.

```bash
pixi install
```

---

## Local Development

### First-time setup

```bash
cp .env.local .env        # use local dev defaults
pixi run local-up         # init PG, start MinIO, create bucket
```

### Open a DuckDB session

```bash
pixi run shell
```

```sql
-- You're in DuckLake. Try it:
CREATE TABLE flights AS
    SELECT * FROM 'https://duckdb.org/data/flights.csv';

SELECT origin, COUNT(*) AS flights
FROM flights
GROUP BY 1
ORDER BY 2 DESC
LIMIT 5;
```

### Subsequent sessions

```bash
pixi run local-up         # starts PG + MinIO if not running
pixi run shell
```

### Stop services

```bash
pixi run local-down
```

---

## Production (Hetzner)

### 1. PostgreSQL

Spin up any PostgreSQL instance — a Hetzner VPS, a managed provider, etc. Create a user and database:

```sql
CREATE USER ducklake WITH PASSWORD 'your-password';
CREATE DATABASE ducklake_catalog OWNER ducklake;
```

### 2. Object Storage

In the Hetzner Cloud Console: **Object Storage -> Create bucket**.
Then: **Object Storage -> Manage keys** to get your access credentials.

### 3. Configure `.env`

```bash
cp .env.prod.sample .env
# Edit .env with your Hetzner credentials
```

### 4. One-time remote setup

```bash
pixi run prod-up          # creates the S3 bucket (idempotent)
```

### 5. Open a session

```bash
pixi run shell
```

---

## Guard: Row-Level Access Control

Based on [ducklake-guard](https://github.com/berndsen-io/ducklake-guard) by [berndsen-io](https://github.com/berndsen-io).

DuckLake Guard adds a security layer on top of your data lake. It restricts which tables a reader can see using two mechanisms:

- **PostgreSQL RLS** -- row-level security on the DuckLake catalog hides table metadata from unauthorized readers
- **S3 bucket policy** -- restricts the reader's S3 key to only the allowed table prefixes

### Setup

```bash
# Load sample data (TPC-H, ~86K rows across 8 tables)
pixi run guard-load-sample

# Create the reader PG role + enable RLS policies
pixi run guard-pg-setup

# Grant access to specific tables
SCHEMA=tpch TABLE=customer pixi run guard-acl-grant

# Restrict the reader's S3 key to the granted table prefix
READER_SCHEMA=tpch READER_TABLE=customer pixi run guard-s3-policy
```

### Verify

```bash
pixi run reader-shell
```

The reader can query `tpch.customer` but cannot see any other tables -- they don't even appear in the catalog.

### Managing access

```bash
# Show current ACL
pixi run guard-acl-show

# Grant another table
SCHEMA=tpch TABLE=orders pixi run guard-acl-grant

# Revoke access
SCHEMA=tpch TABLE=customer pixi run guard-acl-revoke

# Apply both PG RLS + S3 policy in one shot
READER_SCHEMA=tpch READER_TABLE=orders pixi run guard-apply
```

---

## Task reference

| Task | Description |
|------|-------------|
| **Core** | |
| `pixi run local-up` | Start local PG + MinIO + create bucket |
| `pixi run local-down` | Stop local PG + MinIO |
| `pixi run shell` | DuckDB session (reads `.env`) |
| `pixi run status` | Check if PG and MinIO are running |
| `pixi run prod-up` | Create Hetzner S3 bucket (idempotent) |
| **Guard** | |
| `pixi run guard-load-sample` | Load TPC-H sample data |
| `pixi run guard-pg-setup` | Create reader role + RLS policies |
| `pixi run guard-s3-policy` | Restrict reader S3 key to table prefix |
| `pixi run guard-apply` | Run both `guard-pg-setup` + `guard-s3-policy` |
| `pixi run guard-acl-grant` | Grant reader access to a table |
| `pixi run guard-acl-revoke` | Revoke reader access to a table |
| `pixi run guard-acl-show` | Show current ACL entries |
| `pixi run reader-shell` | DuckDB session as restricted reader |

---

## Project layout

```
pixi.toml              <- deps + tasks
init.sql               <- DuckDB S3 config (loaded by shell.sh)
scripts/
  load-env.sh          <- auto-loaded by Pixi; sources .env
  shell.sh             <- builds ATTACH from env vars, launches DuckDB
  reader-shell.sh      <- reader-role DuckDB session
  minio-install.sh     <- downloads MinIO binary
  minio-start.sh       <- starts MinIO in background
  minio-stop.sh        <- stops MinIO
  guard-pg-setup.sh    <- reader role + RLS setup
  guard-acl.sh         <- ACL grant/revoke/show helper
  create_bucket.py     <- idempotent S3 bucket creation
  load_sample_data.py  <- TPC-H data loader
  apply_s3_reader_policy.py <- S3 bucket policy for reader
sql/
  create_reader.sql    <- PostgreSQL reader role DDL
  enable_rls.sql       <- Row Level Security policies
  local.sql            <- standalone DuckDB init (local, hardcoded)
  prod.sql             <- standalone DuckDB init (prod, reads env vars)
.env.local             <- local dev defaults (safe to commit)
.env.sample            <- template for production .env
.env.prod.sample       <- full production template with guard vars
.ducklake/             <- local PG + MinIO data (gitignored)
```

---

## Switching from local to production

The DuckLake catalog format is identical. You can `EXPORT DATABASE` from local and `IMPORT DATABASE` on production, or simply recreate your tables from source data on the production lake.

---

## Resources

- [DuckLake docs](https://ducklake.select/)
- [DuckDB S3 / httpfs](https://duckdb.org/docs/extensions/httpfs/s3api.html)
- [Hetzner Object Storage](https://docs.hetzner.com/storage/object-storage/)
- [Pixi docs](https://pixi.sh/latest/)
