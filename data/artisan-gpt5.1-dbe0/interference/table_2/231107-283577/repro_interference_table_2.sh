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
cd artifact_efficient_test_interference_detection_c/artifact_efficient_test_interference_detection_c
docker load -i data_analysis/test_interference_detection-data_mangling.tgz
cid=$(docker run -d --init --entrypoint bash -v"${PWD}/data_analysis/out":"/data_analysis/out" test_interference_detection/data_mangling -c 'sleep infinity')
docker exec "$cid" /bin/bash --noprofile --norc -c "R -q -e 'setwd(\"data_analysis\"); source(\"analyze_data.R\")'"
docker stop "$cid"
# Extract the permutation reductions table (corresponding to Table 2) to /workspace/repro.txt
cd /workspace
cp artifact_efficient_test_interference_detection_c/artifact_efficient_test_interference_detection_c/data_analysis/out/tables/permutation_reductions.tex /workspace/repro.txt
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
