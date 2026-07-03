#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 4: RQ1: Mixed-effect logistic regression relating the use of comprehensions with the correctness of the change task**

|                  |        |
| ---------------- | ------ |
| **AIC**          | 534.7  |
| **BIC**          | 566.3  |
| **logLik**       | -259.3 |
| **deviance**     | 518.7  |
| **df.residuals** | 378    |

**Scaled residuals:** Min -1.64, 1Q -0.96, Median 0.62, 3Q 0.99, Max 1.59

**Random effects (Groups)** — User (Intercept): Variance 0, Std.Dev. 0; Number of obs: 386, groups: User, 192

**Fixed effects**

| Term | OR | Estimate | Std.Error | z value | Pr(>|z|) |
|---|---:|---:|---:|---:|---:|
| (Intercept) | 1.15 | 0.14 | 0.89 | 0.16 | 0.88 |
| MainFactorProc | 6.11 | 1.81 | 0.60 | 3.00 | 0.02 |
| Compl. | 1.02 | 0.02 | 0.11 | 0.15 | 0.88 |
| Usage Freq. | 0.86 | -0.15 | 0.16 | -0.94 | 0.61 |
| Approvals | 1.00 | -0.00 | 0.00 | -1.12 | 0.61 |
| StudentTrue | 1.19 | 0.18 | 0.66 | 0.27 | 0.88 |
| MainFactorProc:Compl. | 0.65 | -0.43 | 0.17 | -2.58 | 0.03 |

EOTABLE
# Section 2: Artifact download
# Download the replication package from Zenodo and unzip it under /workspace
curl -L -o /workspace/ICSE2024-funcConstructs-Artifacts.zip "https://zenodo.org/records/10554377/files/ICSE2024-funcConstructs-Artifacts.zip"
mkdir -p /workspace/ICSE2024-artifact
unzip -o /workspace/ICSE2024-funcConstructs-Artifacts.zip -d /workspace/ICSE2024-artifact

# Section 3: Reproduction commands (populate from reviewed steps)
# The artifact provides an R script (FuncConstructs-Statistics.r) and helper scripts.
# We prefer to run the analysis in the docker image mdipenta/rexp as suggested in the README,
# but we run the container detached and execute the R script via docker exec.
cd /workspace/ICSE2024-artifact || exit 1

# Pull the docker image that contains the R environment
docker pull mdipenta/rexp:latest

# Run the image detached, mounting the artifact directory into /data inside the container
docker run -d --init --entrypoint bash -v${PWD}:/data --name repro_shell mdipenta/rexp:latest -c 'sleep infinity'

# Execute the R script inside the running container
docker exec repro_shell bash -c "cd /data && R --no-save < FuncConstructs-Statistics.r"

# Copy produced results to workspace
mkdir -p /workspace/results
cp -r /workspace/ICSE2024-artifact/results/* /workspace/results/ 2>/dev/null || true

# Extract Table 4 output (the artifact places tables under results/Tables or similar)
# Try common locations and write the reproduction output to /workspace/repro.txt
if [ -f /workspace/results/Tables/Table4.txt ]; then
  cat /workspace/results/Tables/Table4.txt > /workspace/repro.txt
elif [ -f /workspace/results/Table4.txt ]; then
  cat /workspace/results/Table4.txt > /workspace/repro.txt
elif ls /workspace/results | grep -qi table4; then
  ls -la /workspace/results | sed -n '1,200p' > /workspace/repro.txt
else
  echo "Table 4 not found in results. Listing /workspace/results:" > /workspace/repro.txt
  ls -la /workspace/results >> /workspace/repro.txt 2>&1
fi

# Stop and remove the container
docker stop repro_shell >/dev/null 2>&1 || true
docker rm repro_shell >/dev/null 2>&1 || true

# Section 4: Formatting and submission block
echo '<artisan_submit>'
# Show the reproduced Table 4 (or the listing) delimited for the submission
sed -n '1,500p' /workspace/repro.txt || true
echo '</artisan_submit>'
