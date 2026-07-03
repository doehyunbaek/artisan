#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 2: Summary tables of evaluation results.**

| Analysis               | PPL    | Total Programs | Warnings produced  |
| ---------------------- | ------ | -------------: | ----------------:  |
| Dependency Analysis    | Turing |            117 |                 6  |
| Dependency Analysis    | PyMC   |             97 |                 2  |
| Constraint Verifier    | Turing |            117 |                37  |
| Constraint Verifier    | PyMC   |             97 |                32  |
| HMC Assumption Checker | Gen    |              8 |                 7  |
| Model-Guide Validator  | Pyro   |              8 |                 2  |
EOTABLE

# Section 2: Artifact download
artisan get https://zenodo.org/records/15857114

# Section 3: Reproduction commands
docker load -i lasapp-amd64.tar
docker run -d --init --name lasapp-amd64 --rm --entrypoint bash lasapp-amd64 -c 'sleep infinity'

docker exec lasapp-amd64 /bin/bash --noprofile --norc -c "cd /LASAPP && ./scripts/start_servers.sh"

docker exec lasapp-amd64 /bin/bash --noprofile --norc -c "cd /LASAPP && python3 experiments/evaluate_graph_and_constraints.py -ppl turing > out_turing.txt"
docker exec lasapp-amd64 /bin/bash --noprofile --norc -c "cd /LASAPP && python3 experiments/evaluate_graph_and_constraints.py -ppl pymc > out_pymc.txt"
docker exec lasapp-amd64 /bin/bash --noprofile --norc -c "cd /LASAPP && python3 experiments/evaluate_hmc.py > out_hmc.txt"
docker exec lasapp-amd64 /bin/bash --noprofile --norc -c "cd /LASAPP && python3 experiments/evaluate_guide.py > out_guide.txt"

docker cp lasapp-amd64:/LASAPP/out_turing.txt /workspace/out_turing.txt
docker cp lasapp-amd64:/LASAPP/out_pymc.txt /workspace/out_pymc.txt
docker cp lasapp-amd64:/LASAPP/out_hmc.txt /workspace/out_hmc.txt
docker cp lasapp-amd64:/LASAPP/out_guide.txt /workspace/out_guide.txt

# Parse summary counts from logs
turing_mg_err=$(awk '/Model Graph   Error Count:/ {split($NF,a,"/"); print a[1]}' /workspace/out_turing.txt)
turing_total=$(awk '/Model Graph   Error Count:/ {split($NF,a,"/"); print a[2]}' /workspace/out_turing.txt)
turing_con_err=$(awk '/Constraint    Error Count:/ {split($NF,a,"/"); print a[1]}' /workspace/out_turing.txt)
turing_con_total=$(awk '/Constraint    Error Count:/ {split($NF,a,"/"); print a[2]}' /workspace/out_turing.txt)

pymc_mg_err=$(awk '/Model Graph   Error Count:/ {split($NF,a,"/"); print a[1]}' /workspace/out_pymc.txt)
pymc_total=$(awk '/Model Graph   Error Count:/ {split($NF,a,"/"); print a[2]}' /workspace/out_pymc.txt)
pymc_con_err=$(awk '/Constraint    Error Count:/ {split($NF,a,"/"); print a[1]}' /workspace/out_pymc.txt)

hmc_line=$(grep 'warnings\.' /workspace/out_hmc.txt | tail -n 1)
hmc_warns=$(echo "$hmc_line" | awk '{print $1}')
hmc_total=$(echo "$hmc_line" | awk '{print $3}')

guide_line=$(grep 'warnings\.' /workspace/out_guide.txt | tail -n 1)
guide_warns=$(echo "$guide_line" | awk '{print $1}')
guide_total=$(echo "$guide_line" | awk '{print $3}')

# Write reproduction table
cat > /workspace/repro.txt <<EOT
**Table 2: Summary tables of evaluation results.**

| Analysis               | PPL    | Total Programs | Warnings produced  |
| ---------------------- | ------ | -------------: | ----------------:  |
| Dependency Analysis    | Turing |            $turing_total |                 $turing_mg_err  |
| Dependency Analysis    | PyMC   |             $pymc_total |                 $pymc_mg_err  |
| Constraint Verifier    | Turing |            $turing_con_total |                 $turing_con_err |
| Constraint Verifier    | PyMC   |             $pymc_total |                 $pymc_con_err |
| HMC Assumption Checker | Gen    |              $hmc_total |                 $hmc_warns  |
| Model-Guide Validator  | Pyro   |              $guide_total |                 $guide_warns  |
EOT

docker stop lasapp-amd64 || true

# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
