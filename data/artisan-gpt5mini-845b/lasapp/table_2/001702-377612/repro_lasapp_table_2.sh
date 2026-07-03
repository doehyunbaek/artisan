#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 2: Summary tables of evaluation results.**

| Analysis               | PPL    | Total Programs | Warnings produced  |
| ---------------------- | ------ | -------------: | ----------------:  |
| Dependency Analysis    | Turing |            ??? |                 ?  |
| Dependency Analysis    | PyMC   |             ?? |                 ?  |
| Constraint Verifier    | Turing |            ??? |                 ?? |
| Constraint Verifier    | PyMC   |             ?? |                 ?? |
| HMC Assumption Checker | Gen    |              ? |                 ?  |
| Model-Guide Validator  | Pyro   |              ? |                 ?  |

EOTABLE

# Section 2: Artifact download
artisan get https://zenodo.org/records/15857114

# Section 3: Load provided image (prefer AMD64 tar if available)
if [ -f lasapp-amd64.tar ]; then
  docker load -i lasapp-amd64.tar
  IMAGE_TAG="lasapp-amd64:latest"
elif [ -f lasapp-arm64.tar ]; then
  docker load -i lasapp-arm64.tar
  IMAGE_TAG="lasapp-arm64:latest"
else
  echo "No lasapp image tar found in workspace" >&2
  exit 1
fi

# Run container (detached sleeping shell)
docker rm -f lasapp_table2 >/dev/null 2>&1 || true
docker run -d --name lasapp_table2 --init --entrypoint bash "${IMAGE_TAG}" -c 'sleep infinity' || true

# Best-effort: start language servers inside the container
docker exec lasapp_table2 /bin/bash --noprofile --norc -c "cd /LASAPP && ./scripts/start_servers.sh" >/dev/null 2>&1 || true

# Prepare repro output
echo "Reproduction run for Table 2 - started at $(date)" > /workspace/repro.txt

# Dependency Analysis + Constraint Verifier: Turing
echo $'\n=== Dependency Analysis & Constraint Verifier: Turing ===' >> /workspace/repro.txt
docker exec lasapp_table2 /bin/bash --noprofile --norc -c "cd /LASAPP && python3 experiments/evaluate_graph_and_constraints.py -ppl turing" >> /workspace/repro.txt 2>&1 || echo "Turing run failed or produced errors" >> /workspace/repro.txt

# Dependency Analysis + Constraint Verifier: PyMC
echo $'\n=== Dependency Analysis & Constraint Verifier: PyMC ===' >> /workspace/repro.txt
docker exec lasapp_table2 /bin/bash --noprofile --norc -c "cd /LASAPP && python3 experiments/evaluate_graph_and_constraints.py -ppl pymc" >> /workspace/repro.txt 2>&1 || echo "PyMC run failed or produced errors" >> /workspace/repro.txt

# HMC Assumption Checker: Gen
echo $'\n=== HMC Assumption Checker: Gen ===' >> /workspace/repro.txt
docker exec lasapp_table2 /bin/bash --noprofile --norc -c "cd /LASAPP && python3 experiments/evaluate_hmc.py" >> /workspace/repro.txt 2>&1 || echo "HMC run failed or produced errors" >> /workspace/repro.txt

# Model-Guide Validator: Pyro
echo $'\n=== Model-Guide Validator: Pyro ===' >> /workspace/repro.txt
docker exec lasapp_table2 /bin/bash --noprofile --norc -c "cd /LASAPP && python3 experiments/evaluate_guide.py" >> /workspace/repro.txt 2>&1 || echo "Guide run failed or produced errors" >> /workspace/repro.txt

# Stop servers and cleanup
docker exec lasapp_table2 /bin/bash --noprofile --norc -c "cd /LASAPP && ./scripts/stop_servers.sh" >/dev/null 2>&1 || true
docker rm -f lasapp_table2 >/dev/null 2>&1 || true

# Section 4: Format results
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt || true
echo '</artisan_submit>'
