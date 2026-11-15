"""Run the SQL in sql/ against the source CSV files, without a database server.

Loads every CSV into an in-memory SQLite database laid out like sql/01_schema.sql
(schema "sij"), checks foreign keys, runs every query in sql/questions/, and
compares the reconciliation query with the figures shown in the Power BI report.

The queries are written for PostgreSQL. A few PostgreSQL-only expressions are
translated to SQLite on the fly (see TRANSLATIONS); everything else runs as written.

Usage:
    python tools/verify_sql.py "<folder with the CSV files>" [--show N]
Exit code 0 = all queries ran and the reconciliation matches Power BI.
"""
import csv
import os
import re
import sqlite3
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SQL_DIR = os.path.join(REPO, "sql")

# Headline figures from the Power BI model (full period, no filters).
EXPECTED = {
    "total_loads": 85410,
    "total_revenue": 262_525_800.29,
    "total_billed_revenue": 298_621_428.94,
    "total_miles": 122_159_201,
    "avg_mpg": 6.4477,
    "on_time_pct": 55.6697,
    "avg_detention_min": 91.5375,
    "total_operating_cost": 101_323_565.32,
    "cost_per_mile": 0.8294,
    "avg_fuel_price": 3.8987,
    "total_incidents": 170,
    "preventable_pct": 37.6471,
    "total_claims": 2_653_171.82,
    "avg_utilization_pct": 83.0447,
}

TRANSLATIONS = [
    (r"::(numeric|int|integer|date|text)\b", ""),
    (r"EXTRACT\(YEAR FROM ([\w.]+)\)", r"CAST(strftime('%Y', \1) AS INTEGER)"),
    (r"EXTRACT\(MONTH FROM ([\w.]+)\)", r"CAST(strftime('%m', \1) AS INTEGER)"),
    (r"DATE_TRUNC\('month', ([\w.]+)\)", r"date(\1, 'start of month')"),
    (r"EXTRACT\(EPOCH FROM \(([\w.]+) - ([\w.]+)\)\)", r"((julianday(\1) - julianday(\2)) * 86400.0)"),
    (r"\bGREATEST\(", "MAX("),
]


def parse_schema(path):
    """Return {table: [(column, type, fk_table, fk_column)]} from the DDL file."""
    tables, current = {}, None
    for line in open(path, encoding="utf-8"):
        m = re.match(r"\s*CREATE TABLE sij\.(\w+)", line)
        if m:
            current = m.group(1); tables[current] = []; continue
        if current and line.strip().startswith(")"):
            current = None; continue
        if current:
            m = re.match(r"\s+(\w+)\s+(TEXT|INTEGER|NUMERIC|DATE|TIMESTAMP|BOOLEAN)", line)
            if m and m.group(1).upper() != "PRIMARY":
                fk = re.search(r"REFERENCES sij\.(\w+) \((\w+)\)", line)
                tables[current].append((m.group(1), m.group(2), fk and fk.group(1), fk and fk.group(2)))
    return tables


def convert(value, kind):
    if value == "":
        return None
    if kind == "INTEGER":
        return int(float(value))
    if kind == "NUMERIC":
        return float(value)
    if kind == "BOOLEAN":
        return 1 if value.lower() in ("true", "t", "1") else 0
    return value


def load(db, data_dir, tables):
    for table, cols in tables.items():
        names = [c[0] for c in cols]
        affinity = {"TEXT": "TEXT", "DATE": "TEXT", "TIMESTAMP": "TEXT", "INTEGER": "INTEGER",
                    "NUMERIC": "REAL", "BOOLEAN": "INTEGER"}
        db.execute(f"CREATE TABLE sij.{table} ({', '.join(f'{n} {affinity[k]}' for n, k, _, _ in cols)})")
        with open(os.path.join(data_dir, f"{table}.csv"), encoding="cp1252", newline="") as f:
            reader = csv.DictReader(f)
            rows = ([convert(r[n], k) for n, k, _, _ in cols] for r in reader)
            db.executemany(f"INSERT INTO sij.{table} VALUES ({', '.join('?' * len(cols))})", rows)
    # Index every key column (the first column of each table and every foreign key,
    # plus the columns they point to) so joins run quickly, as with PostgreSQL's
    # primary keys and the indexes in 01_schema.sql.
    keyed = set()
    for table, cols in tables.items():
        keyed.add((table, cols[0][0]))
        for col, _, ref_table, ref_col in cols:
            if ref_table:
                keyed.update({(table, col), (ref_table, ref_col)})
    for table, col in sorted(keyed):
        db.execute(f"CREATE INDEX sij.ix_{table}_{col} ON {table} ({col})")
    db.commit()


def check_foreign_keys(db, tables):
    problems = []
    for table, cols in tables.items():
        for col, _, ref_table, ref_col in cols:
            if not ref_table:
                continue
            n = db.execute(
                f"SELECT COUNT(*) FROM sij.{table} t WHERE t.{col} IS NOT NULL AND NOT EXISTS "
                f"(SELECT 1 FROM sij.{ref_table} r WHERE r.{ref_col} = t.{col})").fetchone()[0]
            if n:
                problems.append(f"{table}.{col}: {n} values not found in {ref_table}.{ref_col}")
    return problems


def statements(path):
    """Yield (title, sql) for each statement; title is the nearest '-- Q..' comment."""
    title, buf = os.path.basename(path), []
    for line in open(path, encoding="utf-8"):
        m = re.match(r"--\s*([QR]\d+\w*\b.*)", line)
        if m and not "".join(buf).strip():
            title = m.group(1).strip()
        if line.lstrip().startswith("--") or line.lstrip().startswith("\\"):
            continue
        line = re.sub(r"\s*--.*$", "", line.rstrip("\n")) + "\n"   # drop trailing comments
        buf.append(line)
        if line.rstrip().endswith(";"):
            sql = "".join(buf).strip()
            buf = []
            if sql:
                yield title, sql
    if "".join(buf).strip():
        raise ValueError(f"{os.path.basename(path)}: statement without a closing ';' near '{title}'")


def translate(sql):
    for pattern, repl in TRANSLATIONS:
        sql = re.sub(pattern, repl, sql, flags=re.IGNORECASE)
    return sql


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    data_dir = sys.argv[1]
    show = int(sys.argv[sys.argv.index("--show") + 1]) if "--show" in sys.argv else 3
    tables = parse_schema(os.path.join(SQL_DIR, "01_schema.sql"))
    db = sqlite3.connect(":memory:")
    db.execute("ATTACH DATABASE ':memory:' AS sij")
    load(db, data_dir, tables)
    print(f"Loaded {len(tables)} tables.")
    fk = check_foreign_keys(db, tables)
    print("Foreign keys:", "all valid" if not fk else "")
    for p in fk:
        print("  ", p)

    failed = 0
    reconciled = False
    qdir = os.path.join(SQL_DIR, "questions")
    for name in sorted(os.listdir(qdir)):
        if not name.endswith(".sql"):
            continue
        print(f"\n=== {name}")
        for title, sql in statements(os.path.join(qdir, name)):
            try:
                cur = db.execute(translate(sql))
                rows = cur.fetchall()
                cols = [d[0] for d in cur.description]
            except sqlite3.Error as e:
                failed += 1
                print(f"  FAIL {title}: {e}")
                continue
            print(f"  ok   {title}  ({len(rows)} rows)")
            for r in rows[:show]:
                print("         ", dict(zip(cols, r)))
            if name.startswith("00_") and rows:
                reconciled = True
                actual = dict(zip(cols, rows[0]))
                before = failed
                for key, want in EXPECTED.items():
                    got = actual.get(key)
                    if got is None or abs(got - want) > max(0.01, abs(want) * 1e-4):
                        failed += 1
                        print(f"  MISMATCH {key}: SQL={got} Power BI={want}")
                    else:
                        print(f"         {key}: {got:,.4f} (Power BI {want:,.4f})")
                print("  reconciliation:", "matches Power BI" if failed == before else "see mismatches")
    if not reconciled:
        failed += 1
        print("\nFAIL: the reconciliation query (00_reconciliation.sql) did not run")
    ok = failed == 0 and not fk
    print("\nRESULT:", "PASS" if ok else f"{failed} failure(s), {len(fk)} foreign-key issue(s)")
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
