#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 4: Bug-finding ability of EvoSuite with different settings. EvoSuite_{Def}: EvoSuite with no fine-tuned options.**

| Tool           |  NPEX | BugSwarm | Defects4J | Genesis | Bears | Total |
| -------------- | ----: | -------: | --------: | ------: | ----: | ----: |
| EvoSuite       | 50.7% |    68.0% |     64.7% |   47.3% | 64.0% | 56.9% |
| EvoSuite_{Def} | 48.8% |    62.7% |     83.3% |   45.3% | 60.0% | 55.7% |

EOTABLE

# Section 2: Artifact download
if [ ! -d /workspace/NPETestArtifact ]; then
  git clone https://github.com/kupl/NPETestArtifact /workspace/NPETestArtifact
else
  echo "NPETestArtifact already present"
fi

# Section 3: Reproduction commands
# Convert the relevant sheet to CSV and compute aggregated percentages
python3 - << 'PY'
import pandas as pd
csv_in='/workspace/NPETestArtifact/rq2_result.xlsx'
# read the specific worksheet
sheet_name='npedetection (2)'
df=pd.read_excel(csv_in, sheet_name=sheet_name)
# write intermediate csv
csv_out='/workspace/npedetection.csv'
df.to_csv(csv_out, index=False)
# compute averages per dataset
df.columns=['dataset','project','class','c1','c2','evosuite','evosuite_def','npetest']
# total row is where dataset is NaN
total_row = df[df['dataset'].isna()].tail(1)
total_vals = total_row[['evosuite','evosuite_def','npetest']].iloc[0].to_dict()
df2=df[df['dataset'].notna()]
datasets=['NPEX','BugSwarm','Defects4J','Genesis','Bears']
res={}
for d in datasets:
    sub=df2[df2['dataset']==d]
    res[d]={'evosuite':sub['evosuite'].mean(),'evosuite_def':sub['evosuite_def'].mean()}
# write reproduction results
out='/workspace/repro.txt'
with open(out,'w') as f:
    f.write('Tool,NPEX,BugSwarm,Defects4J,Genesis,Bears,Total\n')
    f.write('EvoSuite,')
    f.write(f"{res['NPEX']['evosuite']:.1f}% ,{res['BugSwarm']['evosuite']:.1f}% ,{res['Defects4J']['evosuite']:.1f}% ,{res['Genesis']['evosuite']:.1f}% ,{res['Bears']['evosuite']:.1f}% ,{total_vals['evosuite']:.1f}%\n")
    f.write('EvoSuite_Def,')
    f.write(f"{res['NPEX']['evosuite_def']:.1f}% ,{res['BugSwarm']['evosuite_def']:.1f}% ,{res['Defects4J']['evosuite_def']:.1f}% ,{res['Genesis']['evosuite_def']:.1f}% ,{res['Bears']['evosuite_def']:.1f}% ,{total_vals['evosuite_def']:.1f}%\n")
print('Wrote',out)
PY

# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
