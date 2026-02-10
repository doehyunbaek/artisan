#!/usr/bin/bash
curl -L --fail --retry 3 --retry-delay 1 --connect-timeout 30 \
  -o axa-artifact-image.tar \
  https://zenodo.org/api/records/13374578/files/axa-artifact-image.tar/content

docker load -i axa-artifact-image.tar
docker rm -f axa_container >/dev/null 2>&1 || true
docker run -d --init --name axa_container --entrypoint bash axaimage -c 'sleep infinity'
# patch /runner/printLOCs.sh to this
docker exec -i axa_container /bin/bash --noprofile --norc -c "cat > /runner/printLOCs.sh && chmod +x /runner/printLOCs.sh" <<'EOF'
#!/bin/bash

JavaScript_Detector=("ScriptEngineAllocationAnalysis.scala" "ScriptEngineDetector.scala" "ScriptEngineInteractionAnalysisEval.scala" "ScriptEngineInteractionAnalysisGet.scala" "ScriptEngineInteractionAnalysisPut.scala")
Java_Lattice=("CrossLanguageInteraction.scala")
JavaScript_Connector=("TajsConnector.scala" "LocalTAJSAdapter.java" "TajsAdapter.java")
JavaScript_Translator=("JavaJavaScriptTranslator.scala" "translator.scala")
Native_Connector=("SVFModule.java" "SVFJava.java" "CppReference.java" "SVFAnalysisListener.java" "connector.cpp" "svfjava_interface.cpp" "NativeAnalysis.scala" "SVFConnector.scala")
Native_Analysis=("analysis.cpp")
Native_Lattice=("extendlattice.cpp")
Native_Detector=("detectJNICalls.cpp" "detector2.cpp")
Native_Solver=("solver.cpp")
Native_Translator=("SVFTranslator.scala")

printWholeFile() {
        for f; do find / -name $f; done | xargs echo | xargs tokei -o json |  jq -r ".Total.code"
}

printChanges(){
    gitCommit="ebbba0c60121a711736029cca20fa2134908a1ce"
    find . -name $1 | xargs -i git diff $gitCommit {} | grep '^[+-]   ' | grep -v '^[+-]\s*\(/\*\| \*\| \*/\)' | grep -v '^\+\s*$' | grep -v '^\+\s*@' | wc -l
}

js_connector_locs=$(printWholeFile "${JavaScript_Connector[@]}")
native_connector_locs=$(printWholeFile "${Native_Connector[@]}")
js_detector_locs=$(printWholeFile "${JavaScript_Detector[@]}")
native_detector_locs=$(printWholeFile "${Native_Detector[@]}")
js_translator=$(printWholeFile "${JavaScript_Translator[@]}")
native_translator_locs=$(printWholeFile "${Native_Translator[@]}")
native_lattice_locs=$(printWholeFile "${Native_Lattice[@]}")
java_lattice_locs=$(printWholeFile "${Java_Lattice[@]}")
native_solver_locs=$(printWholeFile "${Native_Solver[@]}")

cd /tajs/TAJS-xl/
js_solver_locs=$(printChanges "GenericSolver.java")
js_lattice_locs=$(printChanges "Value.java" "ObjectLabel.java" )

java_detector_locs=$(printWholeFile "JavaDetector.java" "LocalTAJSAdapter.java" "TajsAdapter.java")
#echo -n "changes in NodeTransfer.java: "; printChanges "NodeTransfer.java"
js_visitor_changes=$(($(printChanges "DefaultNodeVisitor.java") + $(printChanges "NodeTransfer.java") + $(printChanges "NodeVisitor.java")))
new_node_types=$(printWholeFile "JNode.java" "JavaNode.java")
#echo -n "Value.java: "; printChanges "Value.java"
#echo -n "ObjectLabel.java: "; printChanges "ObjectLabel.javia"
js_visitor_exchange=$(printChanges "Transfer.java")
cd /
echo -e "=============================================================================================================="
echo -e "Analysis\t" "Detector\t" "Lattice\t" "Solver\t" "Connector\t" "Translator (to Java)\t" "Total"
echo -e "--------------------------------------------------------------------------------------------------------------"
sum_java_changes=$((js_detector_locs + java_lattice_locs))
echo -e "Java\t\t" $js_detector_locs "\t\t" $java_lattice_locs "\t\t" "0" "\t" "0" "\t\t" "-" "\t\t\t" $sum_java_changes " " $java_changes
sum_js_changes=$((java_detector_locs + js_visitor_exchange + js_visitor_changes + js_lattice_locs + new_node_types + js_solver_locs + js_connector_locs + js_translator))
echo -e "JavaScript\t" $java_detector_locs "+" $js_visitor_exchange "\t" $((js_lattice_locs + new_node_types)) "+" $js_visitor_changes "\t" $js_solver_locs "\t" $js_connector_locs "\t\t" $js_translator "\t\t\t" $sum_js_changes
sum_native_changes=$((native_detector_locs + native_lattice_locs + native_solver_locs + native_connector_locs + native_translator_locs))
echo -e "Native\t\t" $native_detector_locs "\t\t" $native_lattice_locs "\t\t" $native_solver_locs "\t" $native_connector_locs "\t\t" $native_translator_locs "\t\t\t" $sum_native_changes
echo -e "==============================================================================================================="
EOF
docker exec axa_container /bin/bash --noprofile --norc -c "/runner/printLOCs.sh" > /workspace/repro.txt

in="/workspace/repro.txt"
out="/workspace/expected.md"
awk '
BEGIN {
  print "**Table 1: Extensions and Changes of Single-Language Analyses for Integration into AXA**"
  print ""
  print "| Analysis   | Detector             | Lattice | Solver | Connector | Translator (to Java) | Total |"
  print "| ---------- | -------------------- | ------: | -----: | --------: | -------------------- | ----- |"
}

function trim(s) { sub(/^[ \t\r\n]+/, "", s); sub(/[ \t\r\n]+$/, "", s); return s }

function parse_line(line, analysis, detector, lattice, solver, connector, translator, total,
                    n, t, i, k, rest, start_idx, end_idx) {

  line = trim(line)
  if (line == "") return 0

  gsub(/[ \t]+/, " ", line)
  n = split(line, t, " ")
  if (n < 7) return 0

  analysis = t[1]
  total = t[n]

  translator = t[n-1]
  connector  = t[n-2]
  solver     = t[n-3]

  start_idx = 2
  end_idx   = n - 4

  k = 0
  for (i = start_idx; i <= end_idx; i++) {
    if (t[i] == "+") { k = i; break }
  }

  if (k > 0 && (k + 1) <= end_idx) {
    detector = t[start_idx] " " t[k] " " t[k+1]
    rest = ""
    for (i = k + 2; i <= end_idx; i++) rest = rest (rest=="" ? "" : " ") t[i]
    lattice = rest
  } else {
    detector = t[start_idx]
    rest = ""
    for (i = start_idx + 1; i <= end_idx; i++) rest = rest (rest=="" ? "" : " ") t[i]
    lattice = rest
  }

  detector = trim(detector)
  lattice  = trim(lattice)

  if (translator == "-") translator = "–"
  if (analysis == "Java") lattice = lattice " (JS)"

  gsub(/[[:space:]]*\+[[:space:]]*/, "+", lattice)

  if (analysis == "Java") {
    printf "| %-10s | %-20s | %7s | %6s | %9s | %-22s | %-5s |\n",
           analysis, detector, lattice, solver, connector, translator, total
  } else {
    printf "| %-10s | %-20s | %7s | %6s | %9s | %-20s | %-5s |\n",
           analysis, detector, lattice, solver, connector, translator, total
  }

  return 1
}

/^=+$/ { next }
/^-+$/ { next }
/^Analysis[[:space:]]+/ { next }

{ parse_line($0) }
' /workspace/repro.txt > /workspace/expected.md
printf '\n' >> /workspace/expected.md

echo '<artisan_submit>'
cat /workspace/expected.md
echo '</artisan_submit>'
