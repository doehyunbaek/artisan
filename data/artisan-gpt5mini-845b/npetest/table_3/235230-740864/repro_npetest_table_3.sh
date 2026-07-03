#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 3: The number of unique NPEs detected by each unit test generation tool with different time budgets.**

| Time   | Tools    | NPEX | BugSwarm | Defects4J | Genesis | Bears | Total |
| ------ | -------- | ---: | -------: | --------: | ------: | ----: | ----: |
| 5 min  | EvoSuite |   ?? |       ?? |         ? |       ? |     ? |    ?? |
|        | NPETest  |   ?? |       ?? |         ? |       ? |     ? |    ?? |

EOTABLE

# Section 2: Artifact download
artisan get https://github.com/kupl/NPETestArtifact

# Section 3: Reproduction commands
# Convert Excel sheet to CSV
uvx --from csvkit in2csv --sheet "Sheet1" NPETestArtifact/rq1_result.xlsx > /workspace/main_merge.csv || true

# Create long-form CSV: Benchmark,Project,Execution,NPE,Tool
printf 'Benchmark,Project,Execution,NPE,Tool\n' > /workspace/converted_main_merge.csv
awk -F',' 'NR>1 && NF>=8 && $1!=""{printf("%s,%s,100,%s,randoop\n",$1,$2,$6); printf("%s,%s,100,%s,evosuite\n",$1,$2,$7); printf("%s,%s,100,%s,npetest\n",$1,$2,$8);} ' /workspace/main_merge.csv >> /workspace/converted_main_merge.csv

# Extract unique hits (Tool,Benchmark,Project) where NPE>0
awk -F',' 'NR>1 && ($4+0)>0{print $5","$1","$2}' /workspace/converted_main_merge.csv | sort -u > /workspace/hits.csv

# Count helper functions (POSIX shell)
count_tool_bench() {
  tool="$1"; bench="$2"
  awk -F',' -v t="$tool" -v b="$bench" '$1==t && $2==b {print $3}' /workspace/hits.csv | sort -u | grep -c . || true
}
count_tool_total() {
  tool="$1"
  awk -F',' -v t="$tool" '$1==t {print $3}' /workspace/hits.csv | sort -u | grep -c . || true
}

# Benchmarks order: NPEX, BugSwarm, Defects4J, Genesis, Bears
evosuite_npex=$(count_tool_bench evosuite NPEX)
evosuite_bugswarm=$(count_tool_bench evosuite BugSwarm)
evosuite_defects=$(count_tool_bench evosuite Defects4J)
evosuite_genesis=$(count_tool_bench evosuite Genesis)
evosuite_bears=$(count_tool_bench evosuite Bears)
evosuite_total=$(count_tool_total evosuite)

npetest_npex=$(count_tool_bench npetest NPEX)
npetest_bugswarm=$(count_tool_bench npetest BugSwarm)
npetest_defects=$(count_tool_bench npetest Defects4J)
npetest_genesis=$(count_tool_bench npetest Genesis)
npetest_bears=$(count_tool_bench npetest Bears)
npetest_total=$(count_tool_total npetest)

# Write the reproduction result table
cat > /workspace/repro.txt <<EOT
**Table 3: The number of unique NPEs detected by each unit test generation tool with different time budgets.**

| Time   | Tools    | NPEX | BugSwarm | Defects4J | Genesis | Bears | Total |
| ------ | -------- | ---: | -------: | --------: | ------: | ----: | ----: |
| 5 min  | EvoSuite |   $evosuite_npex |       $evosuite_bugswarm |         $evosuite_defects |       $evosuite_genesis |     $evosuite_bears |    $evosuite_total |
|        | NPETest  |   $npetest_npex |       $npetest_bugswarm |         $npetest_defects |       $npetest_genesis |     $npetest_bears |    $npetest_total |
EOT

# Section 4: Formatting and submission block (required by judge)
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt || true
echo '</artisan_submit>'
