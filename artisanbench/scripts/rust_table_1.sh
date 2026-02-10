#!/usr/bin/bash
set -euo pipefail

curl -L --fail --retry 3 --retry-delay 1 --connect-timeout 30 -o /workspace/Cargo-Ecosystem-Monitor-ICSE.zip https://zenodo.org/api/records/10496086/files/Cargo-Ecosystem-Monitor-ICSE.zip/content
unzip -o /workspace/Cargo-Ecosystem-Monitor-ICSE.zip -d /workspace/Cargo-Ecosystem-Monitor-ICSE
docker build -t cargo-ecosystem-monitor /workspace/Cargo-Ecosystem-Monitor-ICSE/Cargo-Ecosystem-Monitor
docker rm -f cargo_ecosystem_monitor_run >/dev/null 2>&1 || true
docker run -d --init --entrypoint /bin/bash --name cargo_ecosystem_monitor_run -e POSTGRES_PASSWORD=postgres -w /app --mount type=bind,src=/workspace,target=/app cargo-ecosystem-monitor -c 'sleep infinity'
docker exec cargo_ecosystem_monitor_run /bin/bash --noprofile --norc -c 'cd /app/Cargo-Ecosystem-Monitor-ICSE/Cargo-Ecosystem-Monitor/Code/accuracy_evaluation && python3 -m zipfile -e EDG_Evaluation_20220811.zip . && cargo run --bin summary_release > /app/repro.txt 2>&1'
docker rm -f cargo_ecosystem_monitor_run >/dev/null 2>&1 || true

echo '<artisan_submit>'
python3 - <<'PY'
import re
from decimal import Decimal, ROUND_HALF_UP, InvalidOperation

t = open("/workspace/repro.txt", encoding="utf-8", errors="replace").read()

blk = {
    m.group(1).lower(): m.group(0)
    for m in re.finditer(r"(?s)Dataset:\s*(\w+).*?(?=Dataset:|\Z)", t)
}
order = ["random", "popular", "mostdep"]

def grab(block: str, key: str) -> str:
    m = re.search(rf"{re.escape(key)}\s*=\s*([0-9.]+)%", block)
    if not m:
        return ""
    s = m.group(1)
    try:
        d = Decimal(s)
    except InvalidOperation:
        return ""
    # match common "table rounding": round half up to 2 decimals
    q = d.quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)
    return f"{q}%"

print("**Table 1: Resolution accuracy.**\n")
print("| Dataset Type | Tree Accuracy | Precision | Recall | F1Score |")
print("| ------------ | ------------: | --------: | -----: | ------: |")
for ds in order:
    b = blk.get(ds, "")
    # NOTE: Tree Accuracy column expected one extra leading space → width 13
    print(
        f"| {ds.capitalize():<12} | {grab(b,'Tree Accuracy'):>13} | "
        f"{grab(b,'Precision'):>9} | {grab(b,'Recall'):>6} | {grab(b,'F1Score'):>7} |"
    )

print()  # ensure trailing newline at EOF
PY
echo '</artisan_submit>'
