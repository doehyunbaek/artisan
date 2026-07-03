#!/usr/bin/bash
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
cd /workspace
artisan get https://zenodo.org/records/13767954
# Section 3: Reproduction commands (populate from reviewed steps)
python - <<'PY'
import csv
from pathlib import Path

base = Path("artifact_efficient_test_interference_detection_c") / "artifact_efficient_test_interference_detection_c" / "data_analysis"
perm_path = base / "permutation_data.csv"
testsuite_dir = base / "testsuite"

# Load permutation data indexed by project_name
perm = {}
with perm_path.open() as f:
    reader = csv.DictReader(f)
    for row in reader:
        perm[row["project_name"]] = row

# Projects in Table 2, in the order shown in expected.md
projects_display = [
    "ezstream",
    "flex",
    "imagemagick",
    "libbde",
    "libevt",
    "libevtx",
    "libexe",
    "libfastjson",
    "libfsapfs",
    "libfshfs",
    "libfsntfs",
    "libfsrefs",
    "libfvde",
    "libiff",
    "liblnk",
    "libluksde",
    "libmodi",
    "libnsfdb",
    "libolecf",
    "libqcow",
    "libregf",
    "libscca",
    "libvhdi",
    "libvmdk",
    "libvshadow",
    "libvslvm",
    "naemon-core",
    "numactl",
    "safelib",
    "xz",
]

# Map display name to underlying project_name in permutation_data/testsuites
name_map = {
    "safelib": "safeclib",
}

def fmt_val(v: int, bold: bool) -> str:
    s = f"{v}"
    return f"**{s}**" if bold else s

lines = []
lines.append("### Table 2: Number of all pair-wise permutations ( (P_\\text{max}) ) and after our reductions ( (P_\\text{FD}), (P_\\text{FDF}), (P_\\text{OFS}), (P_\\text{OFSFDF}) ) for all projects with some, but not a total reduction. Bold numbers indicate the minimum number of permutations required after the reductions. Column (TSP_\\text{max}) shows the number of all possible test suite permutations and (TSP_\\text{OFSFDF}) the number of permutations that *would be required* with OFSFDF.\n")
lines.append("|     Project | (P_\\text{max}) | (P_\\text{FD}) | (P_\\text{FDF}) | (P_\\text{OFS}) | (P_\\text{OFSFDF}) | (TSP_\\text{max}) | (TSP_\\text{OFSFDF}) |")
lines.append("| ----------: | -------------: | ------------: | -------------: | -------------: | ----------------: | ---------------: | ------------------: |")

for disp in projects_display:
    key = name_map.get(disp, disp)

    prow = perm[key]
    p_max = int(prow["max_permutations"])
    p_fd = int(prow["fd_permutations"])
    p_fdf = int(prow["fdf_permutations"])
    p_ofs = int(prow["ofs_permutations"])
    p_ofsfdf = int(prow["odf_fdf_permutations"])

    # Determine which permutation values are minimal (to be bolded)
    reduction_vals = [p_fd, p_fdf, p_ofs, p_ofsfdf]
    min_val = min(reduction_vals)

    # Load test-suite permutation data
    tsp_file = testsuite_dir / f"{key}-testsuite-permutation-data.csv"
    with tsp_file.open() as f:
        tsp_reader = csv.DictReader(f)
        trow = next(tsp_reader)

    tsp_max = int(trow["tsp_max"])
    tsp_ofsfdf = int(trow["tsp_ofsfdf"])

    row = "| {proj:>10} | {pmax:13} | {pfd:12} | {pfdf:13} | {pofs:13} | {pofsfdf:16} | {tspmax:15} | {tspofsfdf:18} |".format(
        proj=disp,
        pmax=p_max,
        pfd=fmt_val(p_fd, p_fd == min_val),
        pfdf=fmt_val(p_fdf, p_fdf == min_val),
        pofs=fmt_val(p_ofs, p_ofs == min_val),
        pofsfdf=fmt_val(p_ofsfdf, p_ofsfdf == min_val),
        tspmax=tsp_max,
        tspofsfdf=tsp_ofsfdf,
    )
    lines.append(row)

out_path = Path("/workspace/repro.txt")
out_path.write_text("\n".join(lines) + "\n")
PY
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
