#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 3: Percentage of the 400 experiments per number of states that ran into the one hour timeout.**

| n         |   8 |   9 |  10 |  11 |  12 |  13 |   14 |   15 | 16 | 17 |
| --------- | --: | --: | --: | --: | --: | --: | ---: | ---: | -: | -: |
| timeout % | ?.? | ?.? | ?.? | ?.? | ?.? | ?.? | ??.? | ??.? | ?? | ?? |

EOTABLE
# Section 2: Artifact download
artisan get https://zenodo.org/records/10423670
# Section 3: Reproduction commands (no package installs; compute from existing result files)
cd pmsat-inference-and-publication-artifacts/pmsat-inference || exit 1
python3 - <<'PY' > /workspace/repro.txt
import os, re, sys, json

root = "benchmarkingset-rc2-results"
ns = list(range(8, 18))
totals = {n:0 for n in ns}
timeouts = {n:0 for n in ns}

if not os.path.isdir(root):
    print("Benchmark directory not found:", root, file=sys.stderr)
    sys.exit(1)

def check_timed_out_text(data):
    if re.search(r"time\W*out", data, re.I) or re.search(r"timed\W*out", data, re.I):
        return True
    return False

def check_numeric_timeout(data):
    # look for common numeric fields and consider >=3600 as timeout
    for key in ("time", "solving_time", "total_time", "runtime", "elapsed", "solve_time"):
        for m in re.finditer(r'"' + re.escape(key) + r'"\s*:\s*([0-9]+(?:\.[0-9]+)?)', data):
            try:
                if float(m.group(1)) >= 3600.0:
                    return True
            except:
                pass
    # also try unquoted keys like time: 1234
    for key in ("time", "solving_time", "total_time", "runtime", "elapsed", "solve_time"):
        for m in re.finditer(r'\b' + re.escape(key) + r'\s*[:=]\s*([0-9]+(?:\.[0-9]+)?)', data):
            try:
                if float(m.group(1)) >= 3600.0:
                    return True
            except:
                pass
    return False

for param_dir in os.listdir(root):
    if not param_dir.startswith("n_states="):
        continue
    m = re.search(r"n_states=(\d+)", param_dir)
    if not m:
        continue
    n = int(m.group(1))
    if n not in totals:
        continue
    pdir = os.path.join(root, param_dir)
    if not os.path.isdir(pdir):
        continue
    for entry in os.listdir(pdir):
        expdir = os.path.join(pdir, entry)
        if not os.path.isdir(expdir):
            continue
        totals[n] += 1
        timed = False
        # scan files in experiment dir
        for fname in os.listdir(expdir):
            fpath = os.path.join(expdir, fname)
            if not os.path.isfile(fpath):
                continue
            try:
                with open(fpath, "rb") as f:
                    data = f.read().decode("utf-8", errors="ignore")
            except Exception:
                continue
            if check_timed_out_text(data) or check_numeric_timeout(data):
                timed = True
                break
            # some experiments may have JSON with a field "timeout": true
            if '"timeout"' in data.lower():
                try:
                    j = json.loads(data)
                    if isinstance(j, dict):
                        if j.get("timeout") is True or j.get("timed_out") is True:
                            timed = True
                            break
                except Exception:
                    pass
        if timed:
            timeouts[n] += 1

# write formatted table
print("**Table 3: Percentage of the 400 experiments per number of states that ran into the one hour timeout.**")
print()
hdr = "| n         |" + "".join(f" {x:4d} |" for x in ns)
print(hdr)
print("| --------- |" + "".join(" --: |" for _ in ns))
print("| timeout % |" + "".join(" {0:4.1f} |".format((timeouts[x]/totals[x]*100.0) if totals[x]>0 else 0.0) for x in ns))
print()
print("# details")
for n in ns:
    print(f"n={n}: total={totals[n]}, timeouts={timeouts[n]}, percent={(timeouts[n]/totals[n]*100.0) if totals[n]>0 else 0.0:.1f}")
PY

# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
