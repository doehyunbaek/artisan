#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 5: RQ1: Mixed-effect logistic regression relating the use of MRF with the correctness of the change task**

|                  |        |
| ---------------- | ------ |
| **AIC**          | ???.?  |
| **BIC**          | ???.?  |
| **logLik**       | -???.? |
| **deviance**     | ???.?  |
| **df.residuals** | ???    |

**Scaled residuals:** Min -0.92, 1Q -0.89, Median -0.76, 3Q 1.12, Max 1.52

**Random effects (Groups)** — User (Intercept): Variance 0, Std.Dev. 0; Number of obs: 320, groups: User, 159

**Fixed effects**

| Term | OR | Estimate | Std.Error | z value | Pr(>\|z\|) |
|---|---:|---:|---:|---:|---:|
| (Intercept) | ?.?? | ?.?? | ?.?? | ?.?? | ?.?? |
| MainFactorProc | ?.?? | -?.?? | ?.?? | -?.?? | ?.?? |
| Usage Freq. | ?.?? | -?.?? | ?.?? | -?.?? | ?.?? |
| Approvals | ?.?? | -?.?? | ?.?? | -?.?? | ?.?? |
| StudentTrue | ?.?? | -?.?? | ?.?? | -?.?? | ?.?? |

EOTABLE
# Section 2: Artifact download
artisan get https://zenodo.org/records/10554377

# Section 3: Reproduction commands (produce results into /workspace/repro.txt)
docker pull mdipenta/rexp:latest

# Run the container in detached mode with the workspace mounted at /data
docker run -d --init --entrypoint bash -v${PWD}:/data --name rcnt mdipenta/rexp:latest -c 'sleep infinity'

# Run the R analysis from the nested directory where the R script resides
docker exec rcnt /bin/bash --noprofile --norc -c "cd /data/ICSE2024-funcConstructs-Artifacts/ICSE2024-funcConstructs-Artifacts && R --no-save < FuncConstructs-Statistics.r"

# Stop and remove the container
docker stop rcnt >/dev/null 2>&1 || true
docker rm rcnt >/dev/null 2>&1 || true

# Search the workspace for Table 5 outputs (txt, csv, or tex) and write to /workspace/repro.txt
T5FILE=$(find . -type f -iname "*table*5*.txt" -print -quit)
if [ -n "$T5FILE" ]; then
  cat "$T5FILE" > /workspace/repro.txt
else
  T5FILE=$(find . -type f -iname "*table5*.txt" -print -quit)
  if [ -n "$T5FILE" ]; then
    cat "$T5FILE" > /workspace/repro.txt
  else
    T5CSV=$(find . -type f -iname "*table*5*.csv" -print -quit)
    if [ -n "$T5CSV" ]; then
      cat "$T5CSV" > /workspace/repro.txt
    else
      T5CSV=$(find . -type f -iname "*table5*.csv" -print -quit)
      if [ -n "$T5CSV" ]; then
        cat "$T5CSV" > /workspace/repro.txt
      else
        T5TEX=$(find . -type f -iname "*table*5*.tex" -print -quit)
        if [ -n "$T5TEX" ]; then
          cat "$T5TEX" > /workspace/repro.txt
        else
          echo "Table 5 file not found" > /workspace/repro.txt
        fi
      fi
    fi
  fi
fi

# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
