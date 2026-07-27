"""
Sample data generator for DuckDB & Trino.

Generates Parquet, CSV, and JSON files into /data/duckdb/ and /data/trino/.
Idempotent: skips files that already exist so it never overwrites user data.

Usage:
    python generate.py [--force]

Dependencies: pandas, pyarrow (install with `pip install -q pandas pyarrow`)
"""

import argparse
import random
from datetime import datetime, timedelta
from pathlib import Path

random.seed(42)

DUCKDB_DIR = Path("/data/duckdb")
TRINO_DIR = Path("/data/trino")

# ---------------------------------------------------------------------------
# Sample data generators
# ---------------------------------------------------------------------------

PRODUCTS = [
    ("Laptop Pro", "Electronics", 1299.99),
    ("Wireless Mouse", "Electronics", 29.99),
    ("USB-C Hub", "Electronics", 49.99),
    ("Mechanical Keyboard", "Electronics", 159.99),
    ("4K Monitor", "Electronics", 499.99),
    ("Noise Cancelling Headphones", "Electronics", 249.99),
    ("Standing Desk", "Furniture", 599.99),
    ("Ergonomic Chair", "Furniture", 899.99),
    ("LED Desk Lamp", "Furniture", 79.99),
    ("Bookshelf", "Furniture", 149.99),
    ("Coffee Maker", "Kitchen", 89.99),
    ("Blender", "Kitchen", 59.99),
    ("Air Fryer", "Kitchen", 129.99),
    ("Espresso Machine", "Kitchen", 399.99),
    ("Yoga Mat", "Sports", 34.99),
    ("Resistance Bands Set", "Sports", 24.99),
    ("Dumbbell Set", "Sports", 199.99),
    ("Water Bottle", "Sports", 19.99),
    ("Backpack", "Accessories", 79.99),
    ("Sunglasses", "Accessories", 149.99),
]

REGIONS = ["North America", "Europe", "Asia Pacific", "Latin America", "Africa"]
COUNTRIES = [
    ("United States", "North America"),
    ("Canada", "North America"),
    ("United Kingdom", "Europe"),
    ("Germany", "Europe"),
    ("France", "Europe"),
    ("Japan", "Asia Pacific"),
    ("Australia", "Asia Pacific"),
    ("Singapore", "Asia Pacific"),
    ("Brazil", "Latin America"),
    ("Mexico", "Latin America"),
    ("South Africa", "Africa"),
    ("Nigeria", "Africa"),
]

BROWSERS = ["Chrome", "Firefox", "Safari", "Edge", "Opera"]
DEVICES = ["Desktop", "Mobile", "Tablet"]
PAGES = [
    "/home", "/products", "/cart", "/checkout", "/account",
    "/search?q=laptop", "/search?q=phone", "/blog", "/support", "/pricing",
]


def random_date(start: datetime, end: datetime) -> datetime:
    delta = end - start
    return start + timedelta(seconds=random.randint(0, int(delta.total_seconds())))


def generate_sales_csv(path: Path, rows: int = 1000):
    """Generate sample sales data as CSV."""
    start = datetime(2024, 1, 1)
    end = datetime(2026, 7, 1)

    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", newline="") as f:
        f.write("order_id,date,product,category,region,revenue,quantity,customer_id\n")
        for i in range(1, rows + 1):
            prod_name, prod_cat, prod_price = random.choice(PRODUCTS)
            qty = random.randint(1, 5)
            region = random.choice(REGIONS)
            cust_id = f"C{random.randint(1000, 9999)}"
            dt = random_date(start, end).strftime("%Y-%m-%d")
            f.write(f"{i},{dt},{prod_name},{prod_cat},{region},{prod_price * qty:.2f},{qty},{cust_id}\n")
    print(f"  [OK] {path} ({rows} rows)")


def generate_users_csv(path: Path, rows: int = 100):
    """Generate sample user data as CSV."""
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", newline="") as f:
        f.write("user_id,name,email,country,signup_date,is_active\n")
        for i in range(1, rows + 1):
            country, region = random.choice(COUNTRIES)
            name = f"User_{i}"
            email = f"user{i}@example.com"
            dt = random_date(datetime(2023, 1, 1), datetime(2026, 6, 1)).strftime("%Y-%m-%d")
            active = random.choice(["true", "false"])
            f.write(f"{i},{name},{email},{country},{dt},{active}\n")
    print(f"  [OK] {path} ({rows} rows)")


def generate_products_csv(path: Path):
    """Generate product catalog as CSV."""
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", newline="") as f:
        f.write("product_id,name,category,price,in_stock\n")
        for i, (name, cat, price) in enumerate(PRODUCTS, 1):
            stock = random.randint(0, 500)
            f.write(f"{i},{name},{cat},{price:.2f},{stock}\n")
    print(f"  [OK] {path} ({len(PRODUCTS)} rows)")


def generate_events_json(path: Path, rows: int = 200):
    """Generate sample page view events as JSONL."""
    start = datetime(2026, 6, 1)
    end = datetime(2026, 7, 1)

    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w") as f:
        for i in range(rows):
            ts = random_date(start, end).isoformat()
            page = random.choice(PAGES)
            browser = random.choice(BROWSERS)
            device = random.choice(DEVICES)
            country, _ = random.choice(COUNTRIES)
            duration = random.randint(5, 600)
            f.write(
                f'{{"event_id":{i+1},"timestamp":"{ts}","page":"{page}",'
                f'"browser":"{browser}","device":"{device}","country":"{country}",'
                f'"duration_s":{duration}}}\n'
            )
    print(f"  [OK] {path} ({rows} rows)")


def copy_for_trino(path: Path):
    """Copy DuckDB files into Trino's data dir for sample queries."""
    trino_path = TRINO_DIR / path.name
    if not trino_path.exists():
        TRINO_DIR.mkdir(parents=True, exist_ok=True)
        import shutil
        shutil.copy2(path, trino_path)
        print(f"  [OK] {trino_path}")


def main():
    parser = argparse.ArgumentParser(description="Generate sample data for DuckDB & Trino")
    parser.add_argument("--force", action="store_true", help="Regenerate even if files exist")
    args = parser.parse_args()

    print("Seeding sample data...")

    # --- DuckDB data ---
    duckdb_files = [
        (generate_sales_csv, DUCKDB_DIR / "sales.csv", 1000),
        (generate_users_csv, DUCKDB_DIR / "users.csv", 100),
        (generate_products_csv, DUCKDB_DIR / "products.csv"),
        (generate_events_json, DUCKDB_DIR / "events.jsonl", 200),
    ]

    for gen_func, path, *extra in duckdb_files:
        if args.force or not path.exists():
            gen_func(path, *extra)
        else:
            print(f"  - {path} exists (skipped)")

    # Generate Parquet files using pandas + pyarrow
    try:
        import pandas as pd

        # Sales Parquet
        parquet_path = DUCKDB_DIR / "sales.parquet"
        if args.force or not parquet_path.exists():
            df = pd.read_csv(DUCKDB_DIR / "sales.csv")
            df.to_parquet(parquet_path, index=False)
            print(f"  [OK] {parquet_path} (from CSV)")

        # Users Parquet (partitioned by country for Trino-style queries)
        users_parquet = DUCKDB_DIR / "users.parquet"
        if args.force or not users_parquet.exists():
            df = pd.read_csv(DUCKDB_DIR / "users.csv")
            df.to_parquet(users_parquet, index=False)
            print(f"  [OK] {users_parquet} (from CSV)")

    except ImportError:
        print("  ! pandas/pyarrow not available — skipping Parquet generation")

    # --- Trino data ---
    # Copy the CSV/Parquet files for Trino too
    for f in DUCKDB_DIR.glob("sales.*"):
        copy_for_trino(f)

    for f in DUCKDB_DIR.glob("users.*"):
        copy_for_trino(f)

    # Generate a time-series Parquet file for Trino (federated query examples)
    ts_file = TRINO_DIR / "timeseries.parquet"
    if args.force or not ts_file.exists():
        try:
            import pandas as pd
            import numpy as np

            TRINO_DIR.mkdir(parents=True, exist_ok=True)
            dates = pd.date_range("2024-01-01", "2026-06-30", freq="D")
            df = pd.DataFrame({
                "date": dates,
                "metric": np.random.choice(["page_views", "signups", "revenue"], len(dates)),
                "value": np.random.randint(100, 10000, len(dates)),
                "region": np.random.choice(REGIONS, len(dates)),
            })
            df.to_parquet(ts_file, index=False)
            print(f"  [OK] {ts_file} ({len(df)} rows)")
        except ImportError:
            print("  ! pandas/pyarrow not available — skipping timeseries Parquet")

    print("\nSample data seeded!")


if __name__ == "__main__":
    main()
