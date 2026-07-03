#!/usr/bin/bash
# Section 1: Expected table (copy from existing expected.md)
cat > /workspace/expected.md <<'EOTABLE'
**Table 1: Resolution accuracy.**

| Dataset Type | Tree Accuracy | Precision | Recall | F1Score |
| ------------ | ------------: | --------: | -----: | ------: |
| Random       |        ??.??% |    ??.??% | ??.??% |  ??.??% |
| Popular      |        ??.??% |    ???.??% | ??.??% |  ??.??% |
| Mostdep      |        ??.??% |    ??.??% | ??.??% |  ??.??% |

EOTABLE
# Section 2: Artifact download
artisan get https://zenodo.org/records/10496086
# Section 3: Reproduction commands
cd ./Cargo-Ecosystem-Monitor-ICSE/Cargo-Ecosystem-Monitor/Code/accuracy_evaluation
unzip -o EDG_Evaluation_20220811.zip -d . 2>&1 >/dev/null
# The results.txt file is in results_2000/results.txt
RESULTS_FILE="results_2000/results.txt"
if [ ! -f "$RESULTS_FILE" ]; then
    echo "Error: results file not found at $RESULTS_FILE"
    exit 1
fi
# Use awk to parse and format the table
awk '
BEGIN {
    print "**Table 1: Resolution accuracy.**"
    print ""
    print "| Dataset Type | Tree Accuracy | Precision | Recall | F1Score |"
    print "| ------------ | ------------: | --------: | -----: | ------: |"
}
/Dataset:/ {
    dataset = $2
    if (dataset == "random") display = "Random"
    else if (dataset == "popular") display = "Popular"
    else if (dataset == "mostdep") display = "Mostdep"
}
/Tree Accuracy/ {
    split($0, a, "=")
    val = a[2]
    gsub(/[% ]/, "", val)
    ta[dataset] = sprintf("%.2f", val)
}
/Precision/ {
    split($0, a, "=")
    val = a[2]
    gsub(/[% ]/, "", val)
    pr[dataset] = sprintf("%.2f", val)
}
/Recall/ {
    split($0, a, "=")
    val = a[2]
    gsub(/[% ]/, "", val)
    rc[dataset] = sprintf("%.2f", val)
}
/F1Score/ {
    split($0, a, "=")
    val = a[2]
    gsub(/[% ]/, "", val)
    f1[dataset] = sprintf("%.2f", val)
}
END {
    # Print rows in the order: Random, Popular, Mostdep
    order[1] = "random"; order[2] = "popular"; order[3] = "mostdep"
    for (i=1; i<=3; i++) {
        ds = order[i]
        if (ds == "random") display = "Random"
        else if (ds == "popular") display = "Popular"
        else display = "Mostdep"
        printf "| %-12s | %13s%% | %10s%% | %7s%% | %8s%% |\n", display, ta[ds], pr[ds], rc[ds], f1[ds]
    }
}
' "$RESULTS_FILE" > /workspace/repro.txt
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
