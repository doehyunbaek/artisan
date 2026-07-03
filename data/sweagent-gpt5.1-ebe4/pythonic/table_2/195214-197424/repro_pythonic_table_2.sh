#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 2: Number and percentage of correct/wrong tasks for functional constructs and their procedural alternatives**

| Construct | **Functional — Corr.** | **Functional — Wrong** | **Functional — % Corr.** | **Procedural — Corr.** | **Procedural — Wrong** | **Procedural — % Corr.** |
| --------- | ---------------------: | ---------------------: | -----------------------: | ---------------------: | ---------------------: | -----------------------: |
| Lambda    |                    112 |                     98 |                    53.33 |                    115 |                     95 |                    54.76 |
| Compr.    |                     99 |                    111 |                    47.14 |                    114 |                     96 |                    54.29 |
| MRF       |                     80 |                    130 |                    38.10 |                     85 |                    125 |                    40.48 |

EOTABLE
# Section 2: Artifact download
cd /workspace
curl -L -o ICSE2024-funcConstructs-Artifacts.zip https://zenodo.org/records/10554377/files/ICSE2024-funcConstructs-Artifacts.zip
unzip -q -o ICSE2024-funcConstructs-Artifacts.zip

# Section 3: Reproduction commands (populate from reviewed steps)
cd /workspace/ICSE2024-funcConstructs-Artifacts
# Pull docker image with R and required packages
docker pull mdipenta/rexp:latest
# Start container in background (no interactive TTY)
docker run -d --init --entrypoint bash --name rexp-shell -v${PWD}:/data mdipenta/rexp:latest -c 'sleep infinity'
# Run the R analysis script inside the container to generate results/Table-2-descriptive.csv
docker exec rexp-shell /bin/bash --noprofile --norc -c "cd /data && R --no-save < FuncConstructs-Statistics.r"
# Extract Table 2 numbers into /workspace/repro.txt
cd /workspace/ICSE2024-funcConstructs-Artifacts
{
  echo "**Table 2: Number and percentage of correct/wrong tasks for functional constructs and their procedural alternatives (reproduced)**"
  echo
  echo "| Construct | Functional — Corr. | Functional — Wrong | Functional — % Corr. | Procedural — Corr. | Procedural — Wrong | Procedural — % Corr. |"
  echo "| --------- | ------------------: | ------------------: | --------------------: | ------------------: | ------------------: | --------------------: |"
  tail -n +2 results/Table-2-descriptive.csv | while IFS="," read -r construct Ftrue Ffalse Fperc Ptrue Pfalse Pperc; do
    case "$construct" in
      lambda) label="Lambda";;
      comp) label="Compr.";;
      mrf) label="MRF";;
      *) label=$construct;;
    esac
    printf "| %-9s | %18d | %18d | %20.2f | %18d | %18d | %20.2f |\n" "$label" "$Ftrue" "$Ffalse" "$Fperc" "$Ptrue" "$Pfalse" "$Pperc"
  done
} > /workspace/repro.txt

# Section 4: Formatting and submission block
cd /workspace
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
