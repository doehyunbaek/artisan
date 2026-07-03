#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 1: Extensions and Changes of Single-Language Analyses for Integration into AXA**

| Analysis   | Detector             | Lattice | Solver | Connector | Translator (to Java) | Total |
| ---------- | -------------------- | ------: | -----: | --------: | -------------------- | ----- |
| Java       | ???                  | ?? (JS) |      ? |         ? | –                    | ???   |
| JavaScript | ??? + ?              |   ??+?? |      ? |       ??? | ???                  | ???   |
| Native     | ???                  |     ??? |     ?? |      ???? | ??                   | ????  |

EOTABLE

# Section 2: Artifact download
artisan get https://zenodo.org/records/13374578

# Section 3: Reproduction commands
docker load -i axa-artifact-image.tar
docker rm -f axa_container 2>/dev/null || true
docker run -d --init --name axa_container --entrypoint bash axaimage -c 'sleep infinity'

# Run the official LOC script for Table I (for provenance)
docker exec axa_container /bin/bash --noprofile --norc -c "/runner/printLOCs.sh" > /workspace/locs_raw.txt

# Parse the LOC output and construct the reproduced Table 1 as Markdown
awk 'BEGIN{
    FS = "\t+"
}
function trim(s) {
    gsub(/^[ \t]+|[ \t]+$/, "", s)
    return s
}
$1 == "Java" {
    j_det  = trim($2)
    j_lat  = trim($3)
    j_sol  = trim($4)
    j_conn = trim($5)
    j_tran = trim($6)
    j_tot  = trim($7)
}
$1 == "JavaScript" {
    js_det  = trim($2)
    js_lat  = trim($3)
    js_sol  = trim($4)
    js_conn = trim($5)
    js_tran = trim($6)
    js_tot  = trim($7)
}
$1 == "Native" {
    n_det  = trim($2)
    n_lat  = trim($3)
    n_sol  = trim($4)
    n_conn = trim($5)
    n_tran = trim($6)
    n_tot  = trim($7)
}
END{
    # Map plain hyphen to en dash for the Java translator cell
    if (j_tran == "-") {
        j_tran = "–"
    }

    out = "/workspace/repro.txt"
    print "**Table 1: Extensions and Changes of Single-Language Analyses for Integration into AXA**" > out
    print "" >> out
    print "| Analysis   | Detector   | Lattice | Solver | Connector | Translator (to Java) | Total |" >> out
    print "| ---------- | ---------- | ------: | -----: | --------: | -------------------- | ----- |" >> out

    # Java row: lattice value annotated with (JS)
    printf "| %-9s | %-9s | %7s | %6s | %8s | %-20s | %5s |\n", \
           "Java", j_det, j_lat " (JS)", j_sol, j_conn, j_tran, j_tot >> out

    # JavaScript row
    printf "| %-9s | %-9s | %7s | %6s | %8s | %-20s | %5s |\n", \
           "JavaScript", js_det, js_lat, js_sol, js_conn, js_tran, js_tot >> out

    # Native row
    printf "| %-9s | %-9s | %7s | %6s | %8s | %-20s | %5s |\n", \
           "Native", n_det, n_lat, n_sol, n_conn, n_tran, n_tot >> out
}' /workspace/locs_raw.txt

# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
