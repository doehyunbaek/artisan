#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
### Table 3: Probabilities (in %) of all, unannotated, annotated, primitive annotated, and non-primitive annotated parameters to be type checked ($P(TC(p) \mid p \in \mathcal{P})$). We distinguish between parameters in typed and untyped projects.

| $\mathcal{P}$ | | JS/TS Typed | JS/TS Untyped | Python Typed | Python Untyped |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **$PAR$** | avg | ?.?? | ?.?? | ?.?? | ?.?? |
| | med | ?.?? | ?.?? | ?.?? | ?.?? |
| **$PAR_{unann}$** | avg | ?.?? | ?.?? | ?.?? | ?.?? |
| | med | ?.?? | ?.?? | ?.?? | ?.?? |
| **$PAR_{ann}$** | avg | ?.?? | - | ?.?? | - |
| | med | ?.?? | - | ?.?? | - |
| **$PAR_{prim}$** | avg | ?.?? | - | ?.?? | - |
| | med | ?.? | - | ?.? | - |
| **$PAR_{nonprim}$** | avg | ?.?? | - | ?.?? | - |
| | med | ?.?? | - | ?.? | - |

EOTABLE
# Section 2: Artifact download
artisan get https://zenodo.org/records/13760256 
# Section 3: Reproduction commands (populate from reviewed steps)
python3 - << 'PY' > /workspace/repro.txt
import json

with open("typeconfusion_study/typeconfusion_study/results/evaluation.json") as f:
    data = json.load(f)

rq2 = data["RQ2"]
rq3 = data["RQ3"]["Primitive"]

# JS/TS typed vs untyped
js_typed_par_avg = rq2["JS/TS_annotated"]["par"]["avg"]
js_typed_par_med = rq2["JS/TS_annotated"]["par"]["median"]
js_untyped_par_avg = rq2["JS/TS_unannotated"]["par"]["avg"]
js_untyped_par_med = rq2["JS/TS_unannotated"]["par"]["median"]

js_typed_unann_avg = rq2["JS/TS_annotated"]["par_unann_tc"]["avg"]
js_typed_unann_med = rq2["JS/TS_annotated"]["par_unann_tc"]["median"]
js_untyped_unann_avg = rq2["JS/TS_unannotated"]["par_unann_tc"]["avg"]
js_untyped_unann_med = rq2["JS/TS_unannotated"]["par_unann_tc"]["median"]

js_typed_ann_avg = rq2["JS/TS_annotated"]["par_ann_tc"]["avg"]
js_typed_ann_med = rq2["JS/TS_annotated"]["par_ann_tc"]["median"]

js_prim_avg = rq3["JS/TS"]["par_prim_tc"]["avg"]
js_prim_med = rq3["JS/TS"]["par_prim_tc"]["median"]
js_nonprim_avg = rq3["JS/TS"]["par_non_prim_tc"]["avg"]
js_nonprim_med = rq3["JS/TS"]["par_non_prim_tc"]["median"]

# Python typed vs untyped
py_typed_par_avg = rq2["Python_annotated"]["par"]["avg"]
py_typed_par_med = rq2["Python_annotated"]["par"]["median"]
py_untyped_par_avg = rq2["Python_unannotated"]["par"]["avg"]
py_untyped_par_med = rq2["Python_unannotated"]["par"]["median"]

py_typed_unann_avg = rq2["Python_annotated"]["par_unann_tc"]["avg"]
py_typed_unann_med = rq2["Python_annotated"]["par_unann_tc"]["median"]
py_untyped_unann_avg = rq2["Python_unannotated"]["par_unann_tc"]["avg"]
py_untyped_unann_med = rq2["Python_unannotated"]["par_unann_tc"]["median"]

py_typed_ann_avg = rq2["Python_annotated"]["par_ann_tc"]["avg"]
py_typed_ann_med = rq2["Python_annotated"]["par_ann_tc"]["median"]

py_prim_avg = rq3["Python"]["par_prim_tc"]["avg"]
py_prim_med = rq3["Python"]["par_prim_tc"]["median"]
py_nonprim_avg = rq3["Python"]["par_non_prim_tc"]["avg"]
py_nonprim_med = rq3["Python"]["par_non_prim_tc"]["median"]

def f(x): return f"{x:.2f}"

print("""### Table 3: Probabilities (in %) of all, unannotated, annotated, primitive annotated, and non-primitive annotated parameters to be type checked ($P(TC(p) \\mid p \\in \\mathcal{P})$). We distinguish between parameters in typed and untyped projects.

| $\\mathcal{P}$ | | JS/TS Typed | JS/TS Untyped | Python Typed | Python Untyped |
| :--- | :--- | :--- | :--- | :--- | :--- |""")
# PAR
print(f"| **$PAR$** | avg | {f(js_typed_par_avg)} | {f(js_untyped_par_avg)} | {f(py_typed_par_avg)} | {f(py_untyped_par_avg)} |")
print(f"| | med | {f(js_typed_par_med)} | {f(js_untyped_par_med)} | {f(py_typed_par_med)} | {f(py_untyped_par_med)} |")
# PAR_unann
print(f"| **$PAR_{{unann}}$** | avg | {f(js_typed_unann_avg)} | {f(js_untyped_unann_avg)} | {f(py_typed_unann_avg)} | {f(py_untyped_unann_avg)} |")
print(f"| | med | {f(js_typed_unann_med)} | {f(js_untyped_unann_med)} | {f(py_typed_unann_med)} | {f(py_untyped_unann_med)} |")
# PAR_ann (typed only)
print(f"| **$PAR_{{ann}}$** | avg | {f(js_typed_ann_avg)} | - | {f(py_typed_ann_avg)} | - |")
print(f"| | med | {f(js_typed_ann_med)} | - | {f(py_typed_ann_med)} | - |")
# PAR_prim (typed only)
print(f"| **$PAR_{{prim}}$** | avg | {f(js_prim_avg)} | - | {f(py_prim_avg)} | - |")
print(f"| | med | {f(js_prim_med)} | - | {f(py_prim_med)} | - |")
# PAR_nonprim (typed only)
print(f"| **$PAR_{{nonprim}}$** | avg | {f(js_nonprim_avg)} | - | {f(py_nonprim_avg)} | - |")
print(f"| | med | {f(js_nonprim_med)} | - | {f(py_nonprim_med)} | - |")
PY
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
