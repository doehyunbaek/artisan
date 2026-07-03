#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 1: Resolution accuracy.**

| Dataset Type | Tree Accuracy | Precision | Recall | F1Score |
| ------------ | ------------: | --------: | -----: | ------: |
| Random       |        ??.??% |    ??.??% | ??.??% |  ??.??% |
| Popular      |        ??.??% |    ???.??% | ??.??% |  ??.??% |
| Mostdep      |        ??.??% |    ??.??% | ??.??% |  ??.??% |

EOTABLE
# Section 2: Artifact download (if not already)
artisan get https://zenodo.org/records/10496086
# Section 3: Extract and parse results
cd ./Cargo-Ecosystem-Monitor-ICSE/Cargo-Ecosystem-Monitor/Code/accuracy_evaluation
# Unzip if not already unzipped
if [ ! -d results_2000 ]; then
    unzip -o EDG_Evaluation_20220811.zip 2>&1 >/dev/null
fi
# Locate results.txt
RESULTS_FILE="results_2000/results.txt"
if [ ! -f "$RESULTS_FILE" ]; then
    # maybe the file is in a different location
    RESULTS_FILE=$(find . -name "results.txt" -type f | head -1)
    if [ -z "$RESULTS_FILE" ]; then
        echo "Error: results.txt not found" >&2
        exit 1
    fi
fi
# Parse and output table
awk '
BEGIN {
    # Initialize arrays
    ta["random"]=0; pr["random"]=0; rc["random"]=0; f1["random"]=0;
    ta["popular"]=0; pr["popular"]=0; rc["popular"]=0; f1["popular"]=0;
    ta["mostdep"]=0; pr["mostdep"]=0; rc["mostdep"]=0; f1["mostdep"]=0;
}
/Dataset:/ {
    dataset = $2;
}
/Tree Accuracy/ {
    split($0, a, "=");
    val = a[2];
    gsub(/[% ]/, "", val);
    ta[dataset] = val + 0;  # convert to number
}
/Precision/ {
    split($0, a, "=");
    val = a[2];
    gsub(/[% ]/, "", val);
    pr[dataset] = val + 0;
}
/Recall/ {
    split($0, a, "=");
    val = a[2];
    gsub(/[% ]/, "", val);
    rc[dataset] = val + 0;
}
/F1Score/ {
    split($0, a, "=");
    val = a[2];
    gsub(/[% ]/, "", val);
    f1[dataset] = val + 0;
}
END {
    # Function to round to two decimals
    function round(x) {
        return sprintf("%.2f", x)
    }
    # Print table
    print "**Table 1: Resolution accuracy.**"
    print ""
    print "| Dataset Type | Tree Accuracy | Precision | Recall | F1Score |"
    print "| ------------ | ------------: | --------: | -----: | ------: |"
    printf "| %-12s | %13s%% | %10s%% | %7s%% | %8s%% |\n", "Random", round(ta["random"]), round(pr["random"]), round(rc["random"]), round(f1["random"])
    printf "| %-12s | %13s%% | %10s%% | %7s%% | %8s%% |\n", "Popular", round(ta["popular"]), round(pr["popular"]), round(rc["popular"]), round(f1["popular"])
    printf "| %-12s | %13s%% | %10s%% | %7s%% | %8s%% |\n", "Mostdep", round(ta["mostdep"]), round(rc["mostdep"]), round(rc["mostdep"]), round(f1["mostdep"])
}
' "$RESULTS_FILE" > /workspace/repro.txt
# Section 4: Formatting and submission
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
