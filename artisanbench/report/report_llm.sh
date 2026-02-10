docker run -i --rm --privileged -w /workspace doehyunbaek1/dind bash << 'EOF'
#!/usr/bin/bash

# 1. Download and Extract
curl -L -o GILT_Artifacts.zip "https://zenodo.org/records/10461385/files/GILT_Artifacts.zip?download=1"
unzip GILT_Artifacts.zip > /dev/null

python3 - <<'PY'
import json
nb_path = '/workspace/GILT_Artifacts-main/study/analysis.ipynb'
r_script_path = '/workspace/analysis_exec.R'
data_dir = '/workspace/GILT_Artifacts-main/study'

try:
    with open(nb_path, 'r', encoding='utf-8') as f:
        nb = json.load(f)
    with open(r_script_path, 'w', encoding='utf-8') as out:
        out.write(f"setwd('{data_dir}')\n") 
        out.write("# Extracted code\n")
        for cell in nb.get('cells', []):
            if cell.get('cell_type') == 'code':
                source = ''.join(cell.get('source', []))
                out.write(source + "\n\n")
    print(f"Created {r_script_path}")
except Exception as e:
    print(e)
PY

# Section 4: Run the analysis inside a Docker container
echo "Pulling Docker image and running analysis..."

cp /workspace/GILT_Artifacts-main/study/study_data.csv    /workspace/GILT_Artifacts-main/study/ase_data.csv
docker run --rm \
  -v /workspace:/workspace \
  rocker/verse:4.3.1 \
  /bin/bash -c "
    # 1. Install missing packages (Added plyr and reshape2)
    install2.r --error --skipinstalled lme4 lmerTest MuMIn car rsq parameters plyr reshape2 gridExtra
    
    # 2. Run the extracted script
    Rscript /workspace/analysis_exec.R > /workspace/repro.txt 2>&1
  "
cat /workspace/repro.txt
EOF