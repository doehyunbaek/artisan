#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 1: Benchmark programs**

| Name | C LOC | Rust LOC | #Unions | #Candidates | #Identified |
| --- | --- | --- | --- | --- | --- |
| bc-1.07.1 | 10810 | 16982 | 4 | 1 | 1 |
| binn-3.0** | 5686 | 4298 | 1 | 1 | 0 |
| brotli-1.0.9** | 13173 | 127691 | 6 | 4 | 0 |
| cflow-1.7 | 20601 | 26375 | 5 | 4 | 3 |
| compton* | 8748 | 14084 | 2 | 2 | 2 |
| cpio-2.14 | 35934 | 80929 | 10 | 4 | 3 |
| diffutils-3.10 | 59377 | 95835 | 7 | 5 | 4 |
| enscript-1.6.6 | 34868 | 78749 | 9 | 5 | 3 |
| findutils-4.9.0 | 80015 | 139858 | 13 | 6 | 3 |
| gawk-5.2.2 | 58111 | 140566 | 17 | 10 | 3 |
| glpk-5.0 | 71805 | 145738 | 18 | 14 | 3 |
| gprolog-1.5.0 | 52193 | 74381 | 5 | 2 | 0 |
| grep-3.11 | 64084 | 84902 | 11 | 9 | 6 |
| gzip-1.12 | 20875 | 21605 | 4 | 2 | 1 |
| hiredis* | 7305 | 14042 | 1 | 1 | 1 |
| make-4.4.1 | 28911 | 36336 | 1 | 1 | 1 |
| minilisp* | 722 | 2149 | 1 | 1 | 1 |
| mtools-4.0.43 | 18266 | 37021 | 2 | 1 | 0 |
| nano-7.2 | 42999 | 74994 | 6 | 4 | 3 |
| nettle-3.9 | 61835 | 82742 | 5 | 2 | 1 |
| patch-2.7.6 | 28215 | 103839 | 3 | 1 | 1 |
| php-rdkafka* | 3771 | 28864 | 1 | 1 | 1 |
| pocketlang* | 14267 | 41439 | 4 | 3 | 3 |
| pth-2.0.7 | 7590 | 12950 | 1 | 1 | 1 |
| raygui* | 1588 | 17218 | 1 | 1 | 1 |
| rcs-5.10.1 | 28286 | 36267 | 1 | 1 | 1 |
| screen-4.9.0 | 39335 | 72201 | 1 | 1 | 0 |
| sed-4.9 | 48190 | 68465 | 8 | 7 | 4 |
| shairport* | 4995 | 10118 | 2 | 1 | 1 |
| tar-1.34 | 66172 | 134972 | 16 | 12 | 9 |
| tinyproxy* | 5667 | 12825 | 5 | 2 | 2 |
| twemproxy* | 22738 | 74593 | 8 | 7 | 5 |
| uucp-1.07 | 51123 | 77872 | 3 | 3 | 0 |
| webdis* | 14369 | 29474 | 2 | 2 | 2 |
| wget-1.21.4 | 81188 | 192742 | 6 | 5 | 4 |
| Total |  |  | 190 | 127 | 74 |

EOTABLE
# Section 2: Artifact download
curl -L -o /workspace/README.md https://zenodo.org/records/13373683/files/README.md
curl -L -o /workspace/results.xlsx https://zenodo.org/records/13373683/files/results.xlsx
# Section 3: Reproduction commands (populate from reviewed steps)
# Use csvkit via uvx to convert the Excel file to CSV, then extract the columns
# corresponding to Table 1 and format them as a Markdown table.
uvx --from csvkit in2csv /workspace/results.xlsx \
  | python - << 'PYEOF'
import sys, csv
rows = list(csv.reader(sys.stdin))
header = rows[0]
name_idx = 0
c_loc_idx = header.index('C LOC')
rust_loc_idx = header.index('Rust LOC')
unions_idx = header.index('Unions')
cand_idx = header.index('Candidates')
ident_idx = header.index('Identified')

program_rows = [r for r in rows[1:] if r[0] and r[0] != 'Sum']

with open('/workspace/repro.txt', 'w') as out:
    out.write('**Table 1: Benchmark programs**\n\n')
    out.write('| Name | C LOC | Rust LOC | #Unions | #Candidates | #Identified |\n')
    out.write('| --- | --- | --- | --- | --- | --- |\n')
    total_unions = total_cand = total_ident = 0
    for r in program_rows:
        name = r[name_idx]
        if name.endswith('**') or name.endswith('*'):
            name_out = name
        else:
            if name in {'compton','hiredis','minilisp','php-rdkafka','pocketlang','raygui','shairport','tinyproxy','twemproxy','webdis'}:
                name_out = name + '*'
            elif name in {'binn-3.0','brotli-1.0.9'}:
                name_out = name + '**'
            else:
                name_out = name
        c_loc = int(float(r[c_loc_idx])) if r[c_loc_idx] else ''
        rust_loc = int(float(r[rust_loc_idx])) if r[rust_loc_idx] else ''
        unions = int(float(r[unions_idx])) if r[unions_idx] else 0
        cand = int(float(r[cand_idx])) if r[cand_idx] else 0
        ident = int(float(r[ident_idx])) if r[ident_idx] else 0
        total_unions += unions
        total_cand += cand
        total_ident += ident
        out.write(f'| {name_out} | {c_loc} | {rust_loc} | {unions} | {cand} | {ident} |\n')
    out.write(f'| Total |  |  | {total_unions} | {total_cand} | {total_ident} |\n')
PYEOF
# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
# regenerate repro.txt safely
uvx --from csvkit in2csv /workspace/results.xlsx \
  | python - << 'PYEOF'
import sys, csv
rows = list(csv.reader(sys.stdin))
header = rows[0]
name_idx = 0
c_loc_idx = header.index('C LOC')
rust_loc_idx = header.index('Rust LOC')
unions_idx = header.index('Unions')
cand_idx = header.index('Candidates')
ident_idx = header.index('Identified')

program_rows = [r for r in rows[1:] if r and r[0] and r[0] not in {'Sum'}]

with open('/workspace/repro.txt', 'w') as out:
    out.write('**Table 1: Benchmark programs**\n\n')
    out.write('| Name | C LOC | Rust LOC | #Unions | #Candidates | #Identified |\n')
    out.write('| --- | --- | --- | --- | --- | --- |\n')
    total_unions = total_cand = total_ident = 0
    star_single = {'compton','hiredis','minilisp','php-rdkafka','pocketlang','raygui','shairport','tinyproxy','twemproxy','webdis'}
    star_double = {'binn-3.0','brotli-1.0.9'}
    for r in program_rows:
        name = r[name_idx]
        if name in star_double:
            name_out = name + '**'
        elif name in star_single:
            name_out = name + '*'
        else:
            name_out = name
        c_loc = int(float(r[c_loc_idx])) if r[c_loc_idx] else ''
        rust_loc = int(float(r[rust_loc_idx])) if r[rust_loc_idx] else ''
        unions = int(float(r[unions_idx])) if r[unions_idx] else 0
        cand = int(float(r[cand_idx])) if r[cand_idx] else 0
        ident = int(float(r[ident_idx])) if r[ident_idx] else 0
        total_unions += unions
        total_cand += cand
        total_ident += ident
        out.write(f'| {name_out} | {c_loc} | {rust_loc} | {unions} | {cand} | {ident} |\n')
    out.write(f'| Total |  |  | {total_unions} | {total_cand} | {total_ident} |\n')
PYEOF
