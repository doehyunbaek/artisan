#!/usr/bin/bash
git clone https://github.com/songyahui/infer_TempFix
set -euo pipefail

docker pull yahuuuuui/fse24-prove_n_fix:ubuntu
docker rm -f prove-n-fix
docker run -d --init --name prove-n-fix --entrypoint bash yahuuuuui/fse24-prove_n_fix:ubuntu -lc 'sleep infinity'

docker exec prove-n-fix /bin/bash -lc "cd /home/infer_TempFix && git reset --hard && git checkout main && ./compile"

run_proj() {
  local label="$1"     # pretty name
  local spec="$2"      # spec_*.c in /home/infer_TempFix
  local benchdir="$3"  # bench dir inside container

  {
    echo "=== ${label} ==="
    docker exec prove-n-fix /bin/bash -lc "
      set -euo pipefail
      cd /home/infer_TempFix && cp ${spec} spec.c
      cd ${benchdir} && make clean
      /home/infer_TempFix/infer/bin/tempFix 2>&1 | tee /tmp/pnf.out
      # Keep a hint of the final status line in the container log for debugging
      awk 'tolower(\$0) ~ /failed *assert/ { last = \$0 } END { if (length(last)) print last }' /tmp/pnf.out || true
    " 2>&1 | tail -n 10
  } >> /workspace/repro.txt
}


> /workspace/repro.txt 
run_proj "Swoole"          "spec_Swoole.c"           "/home/benchmarks-RQ1N2/swoole-src"
run_proj "lxc"             "spec_Lxc.c"              "/home/benchmarks-RQ1N2/lxc"
run_proj "WavPack"         "spec_WavPack.c"          "/home/benchmarks-RQ1N2/WavPack"
run_proj "flex"            "spec_flex.c"             "/home/benchmarks-RQ1N2/flex"
run_proj "p11-kit"         "spec_p11.c"              "/home/benchmarks-RQ1N2/p11-kit"
run_proj "x264"            "spec-x264.c"             "/home/benchmarks-RQ1N2/x264"
run_proj "recutils-1.8"    "spec-recutils.c"         "/home/benchmarks-RQ1N2/recutils-1.8"
run_proj "inetutils-1.9.4" "spec-inetutils.c"        "/home/benchmarks-RQ1N2/inetutils-1.9.4"
run_proj "snort-2.9.13"    "spec_snort-2.9.13.c"     "/home/benchmarks-RQ1N2/snort-2.9.13"
run_proj "grub"            "spec_Grub.c"             "/home/benchmarks-RQ1N2/grub"

echo '<artisan_submit>'
python3 - <<'PY'
import re, sys

t = open("/workspace/repro.txt", encoding="utf-8", errors="replace").read()

projects = [
    "Swoole",
    "lxc",
    "WavPack",
    "flex",
    "p11-kit",
    "x264",
    "recutils-1.8",
    "inetutils-1.9.4",
    "snort-2.9.13",
    "grub",
]

caption = "**Table 2. Experimental results for analyzing 10 C projects, comparing with Infer-v1.1.0. Columns **#NPD**, **#ML**, **#RL** record the numbers of null pointer dereferences, memory leaks, and resource leaks, respectively. The number of false positives found by Infer and more true positives found by PROVENFIX are represented by +n and +n respectively. Colunns in #Time record the analysis time spent.**"


# Project header lines
hdr_re = re.compile(r"^===\s*([^=\n].*?)\s*===$", re.M)

# The exact metric lines in your repro.txt (variable spacing)
failed_re = re.compile(r"\[\s*Failed\s+Assert\s*\]\s*(\d+)", re.I)

# Build header positions
headers = list(hdr_re.finditer(t))
idx_by_name = {m.group(1).strip(): i for i, m in enumerate(headers)}

def extract_failed(name: str, debug=False) -> int:
    if name not in idx_by_name:
        if debug:
            print(f"[DBG] {name}: header not found", file=sys.stderr)
        return 0

    i = idx_by_name[name]
    start = headers[i].end()
    end = headers[i+1].start() if i+1 < len(headers) else len(t)
    block = t[start:end]

    vals = failed_re.findall(block)
    if debug:
        print(f"[DBG] {name}: block chars={len(block)} failed_matches={vals}", file=sys.stderr)
    return int(vals[-1]) if vals else 0  # take last in the block

vals = [extract_failed(p, debug=False) for p in projects]
total = sum(vals)

print(caption + "\n")
print("| Project         | Failed Assert |")
print("| --------------- | ------------: |")
for p, v in zip(projects, vals):
    print(f"| {p:<15} | {v:>12} |")
print(f"| **Total**       | **{total}** |")
PY
echo '</artisan_submit>'
