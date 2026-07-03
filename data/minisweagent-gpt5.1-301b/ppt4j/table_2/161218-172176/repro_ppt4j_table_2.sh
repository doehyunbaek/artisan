#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 2: Test results on the dataset**

| Test Suite |        | **Metrics** Acc. | Prec. | Recall |    F1 |
| ---------- | ------ | ---------------: | ----: | -----: | ----: |
| PPT4J      | **D1** |             100% |  100% |   100% |  100% |
|            | **D2** |            98.5% |  100% |  97.0% | 98.5% |

EOTABLE

# Section 2: Artifact download
if [ ! -d "/workspace/ppt4j" ]; then
  git clone https://github.com/pan2013e/ppt4j.git /workspace/ppt4j
fi

# Section 3: Reproduction commands (populate from reviewed steps)
# Pull the official PPT4J Docker image
docker pull zhiyuanpan/ppt4j

# Ensure a clean container named ppt4j_repro
if docker ps -a --format '{{.Names}}' | grep -q '^ppt4j_repro$'; then
  docker rm -f ppt4j_repro >/dev/null 2>&1 || true
fi

# Start a detached PPT4J container following the required pattern
docker run -d --init --name ppt4j_repro --entrypoint bash zhiyuanpan/ppt4j -c 'sleep infinity'

# Run the RQ1 replication script inside the container and capture all output
docker exec ppt4j_repro /bin/bash --noprofile --norc -c "cd /ppt4j && python replicate_rq1.py" | tee /workspace/repro.txt

# Optionally clean up the container
docker rm -f ppt4j_repro >/dev/null 2>&1 || true

# Section 4: Formatting and submission block
echo '<artisan_submit>'
awk '
  /^D1[[:space:]]/ {
    acc1=$2; prec1=$3; rec1=$4; f11=$5;
  }
  /^D2[[:space:]]/ {
    acc2=$2; prec2=$3; rec2=$4; f12=$5;
  }
  END {
    # format as percentage, matching expected style (no decimal when integer)
    function fmt(x,  v) {
      v = x * 100;
      if (v == int(v)) {
        return sprintf("%d%%", v);
      } else {
        return sprintf("%.1f%%", v);
      }
    }
    print "**Table 2: Test results on the dataset**";
    print "";
    print "| Test Suite |        | **Metrics** Acc. | Prec. | Recall |    F1 |";
    print "| ---------- | ------ | ---------------: | ----: | -----: | ----: |";
    printf "| PPT4J      | **D1** | %15s | %5s | %6s | %5s |\n", fmt(acc1), fmt(prec1), fmt(rec1), fmt(f11);
    printf "|            | **D2** | %15s | %5s | %6s | %5s |\n", fmt(acc2), fmt(prec2), fmt(rec2), fmt(f12);
  }
' /workspace/repro.txt
echo '</artisan_submit>'
