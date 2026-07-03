#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 4: Field Immutability Results for OpenJDK**

| Algorithm  | mutable | ⊒ non-trans. | ⊒ depen. | ⊒ trans. |
| ---------- | ------: | -----------: | -------: | -------: |
| Ad-hoc CHA |  23 195 |       24 296 |      108 |   46 368 |
| CHA        |  23 195 |       25 252 |       20 |   45 500 |
| RTA        |  23 195 |        7 352 |      316 |   63 104 |
| XTA        |  23 195 |        2 871 |      316 |   67 585 |

*depen. = dependently immutable, trans. = transitively immutable. Higher numbers in columns to the right = more precise.*

EOTABLE

# Section 2: Artifact download
# Download the Unimocg artifact and extract it
curl -L -o /workspace/Unimocg_Artifact.zip 'https://zenodo.org/records/10890011/files/Unimocg_Artifact.zip?download=1'
unzip -q -o /workspace/Unimocg_Artifact.zip -d /workspace/artifact

# Section 3: Reproduction commands (populate from reviewed steps)
# NOTE: These commands follow the README instructions. They require Docker and sufficient resources.
# Create the container image (this script in the artifact prepares the docker image)
cd /workspace/artifact || exit 1
# createContainer.sh may need sudo; leave as-is to match README
sudo ./createContainer.sh

# Start the container using the required substitution for `docker run -it`:
# Use a named container, mount /workspace so outputs are available on host
docker run -d --init --entrypoint bash --name unimocg_container -v /workspace:/workspace unimocgimage -c 'sleep infinity'

# Execute the immutability analysis and aggregation inside the container.
# The aggregate script prints Table 4; redirect its stdout/stderr to /workspace/repro.txt (host-mounted)
docker exec unimocg_container /bin/bash --noprofile --norc -c "/runner/opalImmutability.sh && python3 /runner/aggregate_opal_immutability.py > /workspace/repro.txt 2>&1"

# Optionally stop and remove the container
docker rm -f unimocg_container || true

# Section 4: Formatting and submission block
echo '<artisan_submit>'
echo '--- EXPECTED TABLE ---'
cat /workspace/expected.md
echo '--- REPRODUCTION OUTPUT (first 2000 lines) ---'
if [ -f /workspace/repro.txt ]; then
  sed -n '1,2000p' /workspace/repro.txt
else
  echo 'repro.txt not found. Check /workspace/artifact/README.md for manual reproduction steps.'
fi
echo '</artisan_submit>'

