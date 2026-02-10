# %%
from __future__ import annotations
import sys
import json
import argparse
from collections import Counter


def count_tables(entry: dict) -> int:
    tables = entry.get("tables", {})
    if not isinstance(tables, dict):
        return 0
    return len(tables)


def main():
    with open("benchmark.json", "r", encoding="utf-8") as f:
        data = json.loads(f.read())

    totals = 0
    results = 0

    for i, paper in enumerate(data, start=1):
        tables = paper.get("tables", {})
        n = len(tables)
        totals += n
        for _table_num, table_data in tables.items():
            non_result_value = table_data.get("non-result")

            if non_result_value is True:
                pass
            elif non_result_value is None:
                results += 1
            else:  # non_result_value is False
                results += 1

    print("# Totals")
    print(f"# Papers: {len(data)}")
    print(f"# Tables: {totals}")
    print(f"# Result tables (non-result=false): {results}")


if __name__ == "__main__":
    main()

# %%
