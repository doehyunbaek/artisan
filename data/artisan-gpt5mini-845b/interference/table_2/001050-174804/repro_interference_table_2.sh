#!/usr/bin/sh
set -euo pipefail

# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
### Table 2: Number of all pair-wise permutations ( (P_\text{max}) ) and after our reductions ( (P_\text{FD}), (P_\text{FDF}), (P_\text{OFS}), (P_\text{OFSFDF}) ) for all projects with some, but not a total reduction. Bold numbers indicate the minimum number of permutations required after the reductions. Column (TSP_\text{max}) shows the number of all possible test suite permutations and (TSP_\text{OFSFDF}) the number of permutations that *would be required* with OFSFDF.

|     Project | (P_\text{max}) | (P_\text{FD}) | (P_\text{FDF}) | (P_\text{OFS}) | (P_\text{OFSFDF}) | (TSP_\text{max}) | (TSP_\text{OFSFDF}) |
| ----------: | -------------: | ------------: | -------------: | -------------: | ----------------: | ---------------: | ------------------: |
|    ezstream |            ??? |           ??? |          **?** |            ??? |             **?** |       ?.??×??^?? |                   ? |
|        flex |          ????? |         ????? |          ????? |      **?????** |         **?????** |        ?.??×??^??? |           ?.??×??^??? |
| imagemagick |            ??? |           ??? |            ??? |            ??? |           **???** |       ?.??×??^?? |          ?.??×??^?? |
|      libbde |              ? |             ? |          **?** |              ? |             **?** |                ? |                   ? |
|      libevt |             ?? |            ?? |             ?? |             ?? |             **?** |               ?? |                   ? |
|     libevtx |             ?? |            ?? |             ?? |             ?? |             **?** |              ??? |                   ? |
|      libexe |              ? |             ? |              ? |              ? |             **?** |                ? |                   ? |
| libfastjson |            ??? |           ??? |            ??? |            ??? |            **??** |       ?.??×??^?? |                  ?? |
|   libfsapfs |             ?? |            ?? |             ?? |             ?? |             **?** |               ?? |                   ? |
|    libfshfs |              ? |             ? |              ? |              ? |             **?** |                ? |                   ? |
|   libfsntfs |             ?? |            ?? |             ?? |             ?? |             **?** |               ?? |                   ? |
|   libfsrefs |              ? |             ? |              ? |              ? |             **?** |                ? |                   ? |
|     libfvde |              ? |             ? |              ? |              ? |             **?** |                ? |                   ? |
|      libiff |           ???? |          ???? |           ???? |           ???? |           **???** |       ?.??×??^?? |            ???????? |
|      liblnk |              ? |             ? |          **?** |              ? |             **?** |                ? |                   ? |
|   libluksde |              ? |             ? |              ? |              ? |             **?** |                ? |                   ? |
|     libmodi |              ? |             ? |              ? |              ? |             **?** |                ? |                   ? |
|    libnsfdb |              ? |             ? |              ? |              ? |             **?** |                ? |                   ? |
|    libolecf |             ?? |            ?? |             ?? |             ?? |             **?** |               ?? |                   ? |
|     libqcow |              ? |             ? |              ? |              ? |             **?** |                ? |                   ? |
|     libregf |             ?? |            ?? |             ?? |             ?? |             **?** |               ?? |                   ? |
|     libscca |              ? |             ? |              ? |              ? |             **?** |                ? |                   ? |
|     libvhdi |              ? |             ? |              ? |              ? |             **?** |                ? |                   ? |
|     libvmdk |              ? |             ? |              ? |              ? |             **?** |                ? |                   ? |
|  libvshadow |              ? |             ? |              ? |              ? |             **?** |                ? |                   ? |
|    libvslvm |              ? |             ? |              ? |              ? |             **?** |                ? |                   ? |
| naemon-core |           ???? |          ???? |           ???? |           ???? |             **?** |       ?.??×??^?? |                   ? |
|     numactl |             ?? |            ?? |             ?? |             ?? |             **?** |           ?????? |                   ? |
|     safelib |          ????? |         ????? |          ????? |          ????? |             **?** |      ?.??×??^??? |                   ? |
|          xz |             ?? |            ?? |             ?? |             ?? |             **?** |             ???? |                   ? |

EOTABLE

# Section 2: Artifact download
artisan get https://zenodo.org/records/13767954

# Section 3: Reproduction steps
ART_DIR="artifact_efficient_test_interference_detection_c/artifact_efficient_test_interference_detection_c"

# Load pre-built image if present, otherwise build
if [ -f "$ART_DIR/test_interference_detection-data_mangling.tgz" ]; then
  docker load -i "$ART_DIR/test_interference_detection-data_mangling.tgz"
else
  docker build -t test_interference_detection/data_mangling -f "$ART_DIR/Dockerfile" "$ART_DIR"
fi

# Ensure out directory exists and run the analysis
mkdir -p "$ART_DIR/data_analysis/out"
docker run --rm -v "$PWD/$ART_DIR/data_analysis/out":/data_analysis/out test_interference_detection/data_mangling /bin/sh -c 'set -e; Rscript -e "setwd(\"data_analysis\"); source(\"analyze_data.R\")"'

# Section 4: Collect produced output to /workspace/repro.txt
OUTFILE="/workspace/repro.txt"
MATCHED_FILE=""
for pat in "*table*.md" "*table*.rmd" "*table*.csv" "*table*.*"; do
  for f in "$ART_DIR/data_analysis/out"/$pat; do
    if [ -f "$f" ]; then
      MATCHED_FILE="$f"
      break 2
    fi
  done
done

if [ -n "$MATCHED_FILE" ]; then
  echo "Using generated output file: $MATCHED_FILE" > "$OUTFILE"
  echo "----" >> "$OUTFILE"
  sed -n '1,10000p' "$MATCHED_FILE" >> "$OUTFILE"
else
  if [ -f "$ART_DIR/data_analysis/permutation_data.csv" ]; then
    echo "# permutation_data.csv (fallback content)" > "$OUTFILE"
    sed -n '1,10000p' "$ART_DIR/data_analysis/permutation_data.csv" >> "$OUTFILE"
  else
    echo "No analysis output found in $ART_DIR/data_analysis/out and no permutation_data.csv fallback; check run logs." > "$OUTFILE"
  fi
fi

# Section 5: Format results
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
