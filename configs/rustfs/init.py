"""
RustFS — one-shot initialization: create bucket + upload sample data.

Runs inside the Docker network (lds-network) and uses boto3 to:
1. Create the lds-data bucket (if it doesn't exist)
2. Upload sample Parquet/CSV/JSON files from the mounted data/duckdb/ dir

Retries the connection to handle the race where RustFS's S3 API (port 9000)
may take a moment to become ready after the healthcheck passes.

Mounts: ./data/duckdb:/data/duckdb:ro
         ./configs/rustfs/init.py:/init.py:ro
Network: lds-network (via compose)
"""

import os
import sys
import time
from pathlib import Path

import boto3
from botocore.config import Config
from botocore.exceptions import EndpointConnectionError, ClientError

ENDPOINT = os.environ.get("RUSTFS_ENDPOINT", "http://rustfs:9000")
ACCESS_KEY = os.environ.get("RUSTFS_ACCESS_KEY", "lds-rustfs-admin")
SECRET_KEY = os.environ.get("RUSTFS_SECRET_KEY", "lds-rustfs-secret-change-me")
BUCKET = os.environ.get("RUSTFS_BUCKET", "lds-data")
DATA_DIR = Path(os.environ.get("DATA_DIR", "/data/duckdb"))

# File formats we know how to read (same as DuckDB's SUPPORTED_FORMATS)
SUPPORTED = {".parquet", ".csv", ".tsv", ".json", ".jsonl", ".arrow", ".feather"}

MAX_RETRIES = 12
RETRY_DELAY = 5  # seconds


def get_client():
    """Return a boto3 S3 client configured for RustFS path-style access."""
    return boto3.client(
        "s3",
        endpoint_url=ENDPOINT,
        aws_access_key_id=ACCESS_KEY,
        aws_secret_access_key=SECRET_KEY,
        region_name="us-east-1",
        use_ssl=False,
        config=Config(
            s3={"addressing_style": "path"},
            retries={"max_attempts": 3, "mode": "standard"},
            connect_timeout=5,
            read_timeout=10,
        ),
    )


def wait_for_rustfs(client) -> bool:
    """Retry connecting to RustFS until it's reachable. Returns True if connected."""
    for attempt in range(1, MAX_RETRIES + 1):
        try:
            client.list_buckets()
            print(f"  ✓ Connected to RustFS at {ENDPOINT}")
            return True
        except EndpointConnectionError as e:
            if attempt < MAX_RETRIES:
                print(f"  ! RustFS not ready yet (attempt {attempt}/{MAX_RETRIES}): {e}")
                print(f"    Retrying in {RETRY_DELAY}s...")
                time.sleep(RETRY_DELAY)
            else:
                print(f"  ✗ RustFS unreachable after {MAX_RETRIES} attempts: {e}")
                return False
        except Exception as e:
            print(f"  ? Unexpected error contacting RustFS: {e}")
            return False
    return False


def ensure_bucket(client) -> bool:
    """Create the bucket if it doesn't exist. Returns True if created."""
    try:
        client.head_bucket(Bucket=BUCKET)
        print(f"  ✓ Bucket '{BUCKET}' already exists")
        return True
    except ClientError:
        pass
    except Exception:
        pass
    try:
        client.create_bucket(Bucket=BUCKET)
        print(f"  ✓ Created bucket '{BUCKET}'")
        return True
    except Exception as e:
        print(f"  ✗ Failed to create bucket '{BUCKET}': {e}")
        return False


def upload_files(client) -> int:
    """Upload supported data files from DATA_DIR to the bucket. Idempotent: skips files already in the bucket."""
    if not DATA_DIR.is_dir():
        print(f"  ! Data directory '{DATA_DIR}' not found — no files to upload")
        return 0

    uploaded = 0
    skipped = 0
    for f in sorted(DATA_DIR.iterdir()):
        if not f.is_file() or f.suffix.lower() not in SUPPORTED:
            continue
        key = f.name
        try:
            client.head_object(Bucket=BUCKET, Key=key)
            print(f"  - {key} already in bucket (skipped)")
            skipped += 1
        except Exception:
            try:
                client.upload_file(str(f), BUCKET, key)
                print(f"  ✓ uploaded {key} ({f.stat().st_size:,} bytes)")
                uploaded += 1
            except Exception as e:
                print(f"  ✗ failed to upload {key}: {e}")

    return uploaded


def main():
    print(f"RustFS init — endpoint: {ENDPOINT}, bucket: {BUCKET}")
    print(f"  Data directory: {DATA_DIR}")
    print()

    client = get_client()

    if not wait_for_rustfs(client):
        print()
        print("FAILED — RustFS S3 API is not reachable.")
        sys.exit(1)

    if not ensure_bucket(client):
        print()
        print("FAILED — could not create or verify bucket.")
        sys.exit(1)

    n = upload_files(client)

    print()
    if n:
        print(f"Done — {n} file(s) uploaded to s3://{BUCKET}/")
    else:
        print(f"Done — no new files uploaded (bucket s3://{BUCKET}/ is up to date)")


if __name__ == "__main__":
    main()
