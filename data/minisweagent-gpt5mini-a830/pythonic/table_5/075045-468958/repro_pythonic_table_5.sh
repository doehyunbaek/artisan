#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 5: RQ1: Mixed-effect logistic regression relating the use of MRF with the correctness of the change task**

|                  |        |
| ---------------- | ------ |
| **AIC**          | 443.0  |
| **BIC**          | 465.6  |
| **logLik**       | -215.5 |
| **deviance**     | 431.0 |
| **df.residuals** | 314    |

**Scaled residuals:** Min -0.92, 1Q -0.89, Median -0.76, 3Q 1.12, Max 1.52

**Random effects (Groups)** — User (Intercept): Variance 0, Std.Dev. 0; Number of obs: 320, groups: User, 159

**Fixed effects**

| Term | OR | Estimate | Std.Error | z value | Pr(>\|z\|) |
|---|---:|---:|---:|---:|---:|
| (Intercept) | 1.64 | 0.50 | 0.96 | 0.52 | 0.93 |
| MainFactorProc | 0.95 | -0.05 | 0.23 | -0.23 | 0.93 |
| Usage Freq. | 0.74 | -0.30 | 0.18 | -1.60 | 0.55 |
| Approvals | 1.00 | -0.00 | 0.00 | -0.29 | 0.93 |
| StudentTrue | 0.94 | -0.07 | 0.76 | -0.09 | 0.93 |

EOTABLE

# Section 2: Artifact download
curl -L -s -o /workspace/zenodo_record.html 'https://zenodo.org/records/10554377'
URL=$(grep -oP 'href="[^"]*files[^"]*"' /workspace/zenodo_record.html | head -n1 | sed -E 's/href="([^"]*)"/\1/') || true
if [ -n "$URL" ]; then
  case "$URL" in /*) URL="https://zenodo.org$URL";; esac
  curl -L -sS -o /workspace/artifact.zip "$URL"
else
  echo "ERROR: Could not find artifact files URL on Zenodo page" >&2
  exit 1
fi

# Section 3: Reproduction commands
unzip -o /workspace/artifact.zip "ICSE2024-funcConstructs-Artifacts/*" -d /workspace || true
mkdir -p /workspace/results
unzip -o /workspace/artifact.zip "ICSE2024-funcConstructs-Artifacts/FuncConstructs-Statistics.r" -d /workspace || true
unzip -o /workspace/artifact.zip "ICSE2024-funcConstructs-Artifacts/working-results/*" -d /workspace || true

# Pull Docker image and run container
docker pull mdipenta/rexp:latest
docker rm -f shell >/dev/null 2>&1 || true
docker run -d --init --entrypoint bash -v /workspace:/data --name shell mdipenta/rexp:latest -c 'sleep infinity'

# Create symlink inside container and execute the R script, capturing output
docker exec shell /bin/bash --noprofile --norc -c "cd /data && ln -sfn ICSE2024-funcConstructs-Artifacts/working-results working-results || true && cat ICSE2024-funcConstructs-Artifacts/FuncConstructs-Statistics.r | R --no-save > /data/repro.txt 2>&1" || true

# Clean up container (outputs remain on host)
docker rm -f shell >/dev/null 2>&1 || true

# Section 4: Output formatting
echo '<artisan_submit>'
if [ -s /workspace/repro.txt ]; then
  sed -n '1,300p' /workspace/repro.txt
fi

if [ -s /workspace/results/Table-5-RQ1-mrf.txt ]; then
  echo '=== Table-5-RQ1-mrf.txt ==='
  sed -n '1,500p' /workspace/results/Table-5-RQ1-mrf.txt
elif [ -s /workspace/results/Table-5-RQ1-mrf-coeff.txt ]; then
  echo '=== Table-5-RQ1-mrf-coeff.txt ==='
  sed -n '1,500p' /workspace/results/Table-5-RQ1-mrf-coeff.txt
else
  echo "Table-5 outputs not found in /workspace/results"
fi
echo '</artisan_submit>'
