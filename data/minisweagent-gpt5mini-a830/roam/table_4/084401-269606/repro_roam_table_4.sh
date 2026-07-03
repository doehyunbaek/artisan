#!/usr/bin/bash
set -euo pipefail

# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 4: The Running Time Results of Each Approach (Shown in Seconds)**

|          | - **ROAM** - |                  |                      |           | ReCDroid | Yakusu |
| :------: | :----------: | :--------------: | :------------------: | :-------: | :------: | :----: |
|          |    **PRM**   | **Event Search** | **Path Recv & Exec** | **Total** |          |        |
| **Avg.** |      19      |        16        |          470         |  **505**  |   2,674  |  3,354 |
| **Mdn.** |       1      |         1        |          111         |  **150**  |   3,600  |  3,600 |

EOTABLE

# Section 2: Artifact download (idempotent)
ART_ZIP=/workspace/ROAM-Artifact.zip
ART_DIR=/workspace/ROAM-Artifact
if [ ! -f "$ART_ZIP" ]; then
  echo "Downloading ROAM artifact..."
  curl -fL --retry 5 --retry-delay 5 -o "$ART_ZIP" "https://zenodo.org/records/11068809/files/ROAM-Artifact.zip?download=1"
fi
if [ ! -d "$ART_DIR" ]; then
  mkdir -p "$ART_DIR"
  unzip -q "$ART_ZIP" -d "$ART_DIR"
fi

# Section 3: Reproduction commands
# Prepare and start Neo4j and the reproduction container using docker-compose as documented.
# The script will then run ROAM for each subject listed in Evaluation/dataset.csv and capture logs to /workspace/repro.txt

BUILDENV_DIR="$ART_DIR/ROAM-Artifact/BuildEnvironment"
ROOT_PROJECT_DEFAULT="$BUILDENV_DIR/../"

# Ensure BuildEnvironment exists
if [ ! -d "$BUILDENV_DIR" ]; then
  echo "ERROR: BuildEnvironment directory not found at $BUILDENV_DIR" >&2
  exit 1
fi

cd "$BUILDENV_DIR"

# Export ROOT_PROJECT as the README suggests
export ROOT_PROJECT="$(pwd)/../"

# Start neo4j using docker-compose (as recommended)
echo "Starting neo4j via docker-compose..."
docker-compose up -d neo4j

# Wait for neo4j to report healthy status (use ancestor filter for neo4j:5.16.0)
echo "Waiting for neo4j to become healthy..."
for i in {1..60}; do
  # use docker ps to look for container using the neo4j:5.16.0 image
  STATUS=$(docker ps --filter "ancestor=neo4j:5.16.0" --format '{{.Status}}' || true)
  if echo "$STATUS" | grep -q "(healthy)"; then
    echo "neo4j is healthy."
    break
  fi
  echo "neo4j not healthy yet (attempt $i), sleeping 5s..."
  sleep 5
done

# Build reproduction-gui-model image (docker-compose will build if needed)
echo "Building reproduction-gui-model container..."
docker-compose build reproduction-gui-model

# Run the reproduction container and execute the batch reproduction commands inside it.
# We use docker-compose run to execute a bash -c that iterates over dataset and runs tool_main.py for each subject.
echo "Running reproduction batch inside reproduction-gui-model container (this may take a long time)..."

docker-compose run reproduction-gui-model bash -c '
set -euo pipefail
# Ensure we are in the ReproductionTool directory of the mounted project
cd "$ROOT_PROJECT/ROAM-Artifact/ReproductionTool" || exit 1

# Prepare output capture
HOST_REPRO="/workspace/repro.txt"
echo "Reproduction started at $(date)" > "$HOST_REPRO"

DATASET_CSV="$ROOT_PROJECT/ROAM-Artifact/Evaluation/dataset.csv"
if [ ! -f "$DATASET_CSV" ]; then
  echo "ERROR: dataset.csv not found at $DATASET_CSV" >> "$HOST_REPRO"
  exit 1
fi

# Iterate over subjects (assumes first column is subject id and CSV has header)
awk -F, "NR>1{print \$1}" "$DATASET_CSV" | while read -r appId; do
  echo "=== Processing subject: $appId ===" | tee -a "$HOST_REPRO"
  # Prepare test_input
  mkdir -p test_input
  # copy apk
  APK_SRC="$ROOT_PROJECT/ROAM-Artifact/Evaluation/dataset/apks/${appId}.apk"
  if [ -f "$APK_SRC" ]; then
    cp "$APK_SRC" test_input/app.apk
  else
    echo "APK not found for ${appId} at $APK_SRC" | tee -a "$HOST_REPRO"
    continue
  fi
  # copy s2r (step entities)
  S2R_SRC="$ROOT_PROJECT/ROAM-Artifact/Evaluation/dataset/s2rs/${appId}.json"
  if [ -f "$S2R_SRC" ]; then
    cp "$S2R_SRC" test_input/s2r_groundtruth.json
  else
    echo "s2r groundtruth not found for ${appId} at $S2R_SRC" | tee -a "$HOST_REPRO"
    continue
  fi
  # prepare crash message if exists
  CRASH_SRC="$ROOT_PROJECT/ROAM-Artifact/Evaluation/dataset/crash_msgs/${appId}.txt"
  if [ -f "$CRASH_SRC" ]; then
    cp "$CRASH_SRC" test_input/errormsg.txt
    CRASH_ARG="--crashMsgPath ./test_input/errormsg.txt"
  else
    CRASH_ARG="-nonCrashReport"
  fi
  # prepare UTG/gui_model
  GUI_SRC_DIR="$ROOT_PROJECT/ROAM-Artifact/Evaluation/dataset/utgs/${appId}"
  mkdir -p test_input/gui_model
  # copy all files under the subject UTG directory if exists
  if [ -d "$GUI_SRC_DIR" ]; then
    rm -rf test_input/gui_model/* || true
    cp -r "$GUI_SRC_DIR"/* test_input/gui_model/ || true
  else
    echo "UTG folder not found for ${appId} at $GUI_SRC_DIR" | tee -a "$HOST_REPRO"
  fi

  # Run the tool and capture timestamps in stdout/stderr
  START_TS=$(date +%s)
  echo "Start running $appId at $(date)" | tee -a "$HOST_REPRO"
  # output dir per subject
  OUTDIR="./output/${appId}"
  mkdir -p "$OUTDIR"
  # choose an Android version; this is a best-effort choice. Adjust per dataset if needed.
  ANDROID_VER="Android 7"
  # run ROAM
  python3 -u tool_main.py \
    --appId "$appId" \
    --apkPath ./test_input/app.apk \
    --outputDir "$OUTDIR" \
    --s2rsPath ./test_input/s2r_groundtruth.json \
    $CRASH_ARG \
    --utgPath ./test_input/gui_model \
    --androidVersion "$ANDROID_VER" \
    -createNewEmulator \
    2>&1 | tee -a "$HOST_REPRO"
  END_TS=$(date +%s)
  ELAPSED=$((END_TS-START_TS))
  echo "Finished $appId at $(date) (elapsed ${ELAPSED}s)" | tee -a "$HOST_REPRO"
done

echo "Reproduction finished at $(date)" >> "$HOST_REPRO"
'

# Section 4: Formatting and submission block
echo '<artisan_submit>'
# The reproduction logs are captured to /workspace/repro.txt by the above run.
# Present repro.txt (or a summary) between the tags for the grader to parse.
if [ -f /workspace/repro.txt ]; then
  # print a short header and the last 200 lines to avoid huge output
  echo "=== /workspace/repro.txt (last 200 lines) ==="
  tail -n 200 /workspace/repro.txt || true
else
  echo "No reproduction log found at /workspace/repro.txt"
fi
echo '</artisan_submit>'

# Make the script executable
chmod +x /workspace/repro_roam_table_4.sh

