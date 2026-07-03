#!/usr/bin/bash
# Section 1: Expected table (as provided)
cat > /workspace/expected.md <<'EOTABLE'
**Table 3: Evaluation Results**

| Project Name          | Summary                                                                                | Annotations | Total Warnings |
| --------------------- | -------------------------------------------------------------------------------------- | ----------: | -------------: |
| MarginSwap            | Dex project for margin trading on Uniswap and Sushiswap                                |           ? |              ? |
| Vader Protocol        | Yield project for a collateralized stablecoin                                          |          ?? |              ? |
| PoolTogether          | Gaming service on yield interest                                                       |          ?? |              ? |
| Tracer                | Derivative project that supports perpetual markets                                     |          ?? |              ? |
| Yield Micro           | Lending project supporting borrowing, lending, and liquidity                           |           ? |              ? |
| Sushi Trident         | Dex project for deploying personalized liquidity markets                               |          ?? |              ? |
| yAxis                 | Yield project where users’ aggregated funds are used in strategies for yield           |           ? |              ? |
| Badger Dao            | Yield project                                                                          |           ? |              ? |
| Wild Credit           | Lending project relying on pairs of assets instead of a pool                           |          ?? |              ? |
| PoolTogether v4       | Gaming service on yield interest                                                       |           ? |              ? |
| Sushi Trident p2      | Dex project for deploying personalized liquidity markets                               |          ?? |             ?? |
| Swell                 | Yield project that uses set orders for Yield claiming                                  |           ? |              ? |
| Covalent              | Users delegate commissions to a Validators, which stakes the funds for interest        |           ? |              ? |
| yAxis p2              | Yield project where users’ aggregated funds are used in strategies for yield           |           ? |              ? |
| Perennial             | Derivative project supporting synthetic token perpetual markets                        |           ? |              ? |
| Yeti Finance          | Lending project made against a contract specific token                                 |           ? |              ? |
| Vader Protocol p3     | Yield project for a collateralized stablecoin                                          |           ? |              ? |
| InsureDao             | Insurance markets where buyers pay premium for protection against losses               |          ?? |              ? |
| Rocket Joe            | Dex project where users exchange funds in return for new project liquidity             |           ? |              ? |
| Concur Finance        | Yield project                                                                          |           ? |              ? |
| Biconomy Hyphen       | Cross Chain project where users can deposit and withdraw for pools on different chains |           ? |              ? |
| Volt                  | Dex project which conserves the value of user funds against inflation                  |           ? |              ? |
| Badger Dao p3         | Yield project                                                                          |           ? |              ? |
| Tigris Trade          | Dex project utilizing off-chain oracles to provide real-time prices                    |          ?? |              ? |
| **Total**             |                                                                                        |             |             ?? |
EOTABLE

# Section 2: Artifact download
artisan get https://zenodo.org/records/10449162

# Section 3: Reproduction commands
# 3.1: Pull the Docker image used in the README
docker pull icse24sctype/full:latest

# 3.2: Start a long-running container
CID=$(docker run -d --init --entrypoint bash icse24sctype/full:latest -c 'sleep infinity')

# 3.3: Inside the container, run the full benchmark script and capture output
docker exec "$CID" /bin/bash --noprofile --norc -c "cd /home/slither/slither && bash test_benchmark_final.sh" > /workspace/full_benchmark_output.txt 2>&1

# 3.4: Derive Total Warnings per project from the benchmark output.
# We rely on the '[*] Tested X warnings for Project' marker lines emitted by test_benchmark_final.sh.
awk '
  /^\[\*\] Tested/ {
    # line looks like: [*] Tested 4 warnings for Vader Protocol P1
    n=$3
    proj=$0
    sub(/^.*for /, "", proj)
    gsub(/ *$/, "", proj)
    print proj "|" n
  }
' /workspace/full_benchmark_output.txt > /workspace/project_warnings_raw.txt

# 3.5: Normalize project names to the Table 3 naming and filter to the 24 rows in the table.
python - <<'PYWARN'
import pathlib

raw_path = pathlib.Path("/workspace/project_warnings_raw.txt")
mapping = {}

if raw_path.exists():
    for line in raw_path.read_text().splitlines():
        if "|" not in line:
            continue
        proj, num = line.split("|", 1)
        proj = proj.strip()
        num = num.strip()
        name_map = {
            "MarginSwap": "MarginSwap",
            "Vader Protocol P1": "Vader Protocol",
            "PoolTogether": "PoolTogether",
            "Tracer": "Tracer",
            "Yield Micro": "Yield Micro",
            "Sushi Tridnet": "Sushi Trident",
            "yAxis": "yAxis",
            "BadgerDao": "Badger Dao",
            "Wild Credit": "Wild Credit",
            "Pool Together v4": "PoolTogether v4",
            "Sushi Trident": "Sushi Trident p2",
            "Swivel": "Swell",
            "Covalent": "Covalent",
            "Badger Dao p2": None,
            "Vader Protocol p2": None,
            "yAxis p2": "yAxis p2",
            "Malt Finance": None,
            "Perennial": "Perennial",
            "Sublime": None,
            "Yeti Finance": "Yeti Finance",
            "Vader Protocol p3": "Vader Protocol p3",
            "InsureDao": "InsureDao",
            "Rocket Joe": "Rocket Joe",
            "Concur Finance": "Concur Finance",
            "Biconomy Hyphen": "Biconomy Hyphen",
            "Sublime p2": None,
            "Volt": "Volt",
            "Badger Dao p3": "Badger Dao p3",
            "Tigris Trade": "Tigris Trade",
        }
        tbl_name = name_map.get(proj, proj)
        if tbl_name is None:
            continue
        mapping[tbl_name] = int(num)

out = []
for k in sorted(mapping.keys()):
    out.append(f"{k}|{mapping[k]}")
pathlib.Path("/workspace/table3_warnings.txt").write_text("\n".join(out) + ("\n" if out else ""))
PYWARN

# 3.6: Compute annotation counts per project by counting non-empty, non-comment lines
# in *_types*.txt and *_ftypes*.txt under the relevant Benchmark subdirectories.
python - <<'PYANN'
import pathlib

bench_root = pathlib.Path("/workspace") / "ScType-publish_onto_zenodo" / "NioTheFirst-ScType-0b10e09" / "Benchmark"

project_dirs = {
    "MarginSwap": ["MarginSwap/contracts"],
    "Vader Protocol": ["Vader_Protocol_p1/vader-protocol/contracts"],
    "PoolTogether": ["PoolTogether/contracts/yield-source"],
    "Tracer": ["Tracer/src/contracts/lib"],
    "Yield Micro": ["Yield_Micro/contracts/oracles/composite"],
    "Sushi Trident": ["Sushi_Trident/trident/contracts/pool"],
    "yAxis": ["yAxis/contracts/v3"],
    "Badger Dao": ["BadgerDao/veCVX/contracts"],
    "Wild Credit": ["Wild_Credit/contracts"],
    "PoolTogether v4": ["PoolTogether_v4/v4-core/contracts"],
    "Sushi Trident p2": ["Sushi_Trident_p2/trident/contracts/pool/concentrated"],
    "Swell": ["Swivel/gost/build/swivel"],
    "Covalent": ["Covalent/contracts"],
    "yAxis p2": ["yAxis_p2/contracts/v3/alchemix/libraries/alchemist"],
    "Perennial": ["Perennial/protocol/contracts/collateral/types"],
    "Yeti Finance": ["Yeti_Finance/packages/contracts/contracts/YETI"],
    "Vader Protocol p3": ["Vader_Protocol_p3/contracts/lbt"],
    "InsureDao": ["InsureDao/contracts"],
    "Rocket Joe": ["Rocket_Joe/contracts"],
    "Concur Finance": ["Concur_Finance/contracts"],
    "Biconomy Hyphen": ["Biconomy_Hyphen/contracts/hyphen"],
    "Volt": ["Volt/contracts/oracle"],
    "Badger Dao p3": ["Badger_Dao_p3/src"],
    "Tigris Trade": ["Tigris_Trade/contracts"],
}

def count_annotations_in_dir(d: pathlib.Path) -> int:
    total = 0
    if not d.exists():
        return 0
    for path in d.rglob("*types*.txt"):
        with path.open() as f:
            for line in f:
                s = line.strip()
                if not s or s.startswith("#"):
                    continue
                total += 1
    for path in d.rglob("*ftypes*.txt"):
        with path.open() as f:
            for line in f:
                s = line.strip()
                if not s or s.startswith("#"):
                    continue
                total += 1
    return total

rows = []
for proj, rel_dirs in project_dirs.items():
    count = 0
    for rel in rel_dirs:
        count += count_annotations_in_dir(bench_root / rel)
    rows.append((proj, count))

out_lines = [f"{p}|{c}" for p, c in rows]
path = pathlib.Path("/workspace/table3_annotations.txt")
path.write_text("\n".join(out_lines) + ("\n" if out_lines else ""))
PYANN

# 3.7: Combine annotations and warnings into the reproduced Table 3 in /workspace/repro.txt
python - <<'PYCOMB'
import pathlib

ann_path = pathlib.Path("/workspace/table3_annotations.txt")
warn_path = pathlib.Path("/workspace/table3_warnings.txt")
repro_path = pathlib.Path("/workspace/repro.txt")

ann = {}
if ann_path.exists():
    for line in ann_path.read_text().splitlines():
        if "|" not in line:
            continue
        proj, num = line.split("|", 1)
        ann[proj.strip()] = int(num.strip())

warn = {}
if warn_path.exists():
    for line in warn_path.read_text().splitlines():
        if "|" not in line:
            continue
        proj, num = line.split("|", 1)
        warn[proj.strip()] = int(num.strip())

projects = [
    "MarginSwap",
    "Vader Protocol",
    "PoolTogether",
    "Tracer",
    "Yield Micro",
    "Sushi Trident",
    "yAxis",
    "Badger Dao",
    "Wild Credit",
    "PoolTogether v4",
    "Sushi Trident p2",
    "Swell",
    "Covalent",
    "yAxis p2",
    "Perennial",
    "Yeti Finance",
    "Vader Protocol p3",
    "InsureDao",
    "Rocket Joe",
    "Concur Finance",
    "Biconomy Hyphen",
    "Volt",
    "Badger Dao p3",
    "Tigris Trade",
]

summaries = {
    "MarginSwap": "Dex project for margin trading on Uniswap and Sushiswap",
    "Vader Protocol": "Yield project for a collateralized stablecoin",
    "PoolTogether": "Gaming service on yield interest",
    "Tracer": "Derivative project that supports perpetual markets",
    "Yield Micro": "Lending project supporting borrowing, lending, and liquidity",
    "Sushi Trident": "Dex project for deploying personalized liquidity markets",
    "yAxis": "Yield project where users’ aggregated funds are used in strategies for yield",
    "Badger Dao": "Yield project",
    "Wild Credit": "Lending project relying on pairs of assets instead of a pool",
    "PoolTogether v4": "Gaming service on yield interest",
    "Sushi Trident p2": "Dex project for deploying personalized liquidity markets",
    "Swell": "Yield project that uses set orders for Yield claiming",
    "Covalent": "Users delegate commissions to a Validators, which stakes the funds for interest",
    "yAxis p2": "Yield project where users’ aggregated funds are used in strategies for yield",
    "Perennial": "Derivative project supporting synthetic token perpetual markets",
    "Yeti Finance": "Lending project made against a contract specific token",
    "Vader Protocol p3": "Yield project for a collateralized stablecoin",
    "InsureDao": "Insurance markets where buyers pay premium for protection against losses",
    "Rocket Joe": "Dex project where users exchange funds in return for new project liquidity",
    "Concur Finance": "Yield project",
    "Biconomy Hyphen": "Cross Chain project where users can deposit and withdraw for pools on different chains",
    "Volt": "Dex project which conserves the value of user funds against inflation",
    "Badger Dao p3": "Yield project",
    "Tigris Trade": "Dex project utilizing off-chain oracles to provide real-time prices",
}

lines = []
lines.append("**Table 3: Evaluation Results (Reproduced)**\n")
lines.append("| Project Name          | Summary                                                                                | Annotations | Total Warnings |")
lines.append("| --------------------- | -------------------------------------------------------------------------------------- | ----------: | -------------: |")

total_ann = 0
total_warn = 0

for proj in projects:
    a = ann.get(proj, 0)
    w = warn.get(proj, 0)
    total_ann += a
    total_warn += w
    summary = summaries.get(proj, "")
    lines.append(f"| {proj:<20} | {summary:<86} | {a:10d} | {w:13d} |")

lines.append(f"| **Total**             |                                                                                        | {total_ann:11d} | {total_warn:13d} |")

repro_path.write_text("\n".join(lines) + "\n")
PYCOMB

# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
