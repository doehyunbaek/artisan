#!/usr/bin/bash
docker pull kaistplrg/urcrat:ase2024
docker run -d --init --entrypoint bash --name urcrat_ase kaistplrg/urcrat:ase2024 -c 'sleep infinity'
docker exec urcrat_ase /bin/bash --noprofile --norc -c "size.sh" > /workspace/repro.txt
docker exec urcrat_ase /bin/bash --noprofile --norc -c "run.sh" >> /workspace/repro.txt 2>&1

echo '<artisan_submit>'
python3 - <<'PY'
order = ["bc-1.07.1","binn-3.0","brotli-1.0.9","cflow-1.7","compton","cpio-2.14","diffutils-3.10","enscript-1.6.6",
         "findutils-4.9.0","gawk-5.2.2","glpk-5.0","gprolog-1.5.0","grep-3.11","gzip-1.12","hiredis","make-4.4.1",
         "minilisp","mtools-4.0.43","nano-7.2","nettle-3.9","patch-2.7.6","php-rdkafka","pocketlang","pth-2.0.7",
         "raygui","rcs-5.10.1","screen-4.9.0","sed-4.9","shairport","tar-1.34","tinyproxy","twemproxy","uucp-1.07",
         "webdis","wget-1.21.4"]

# Match expected display names exactly (pth has NO '*')
disp = {
    "binn-3.0":"binn-3.0**",
    "brotli-1.0.9":"brotli-1.0.9**",
    "compton":"compton*",
    "hiredis":"hiredis*",
    "minilisp":"minilisp*",
    "php-rdkafka":"php-rdkafka*",
    "pocketlang":"pocketlang*",
    "raygui":"raygui*",
    "shairport":"shairport*",
    "tinyproxy":"tinyproxy*",
    "twemproxy":"twemproxy*",
    "webdis":"webdis*",
}

loc, stats = {}, {}

for l in open("/workspace/repro.txt", encoding="utf-8", errors="replace"):
    p = l.split()
    if not p:
        continue

    # size table header line: "c loc   rs loc" -> skip
    if len(p) >= 4 and p[0] == "c" and p[1] == "loc":
        continue

    # size.sh lines: "<CLOC> <RLOC> <name>"
    if len(p) == 3 and p[0].isdigit() and p[1].isdigit():
        loc[p[2]] = (int(p[0]), int(p[1]))
        continue

    # run.sh lines: integers then program name at end
    # expected wants the FIRST three ints: unions, candidates, identified
    if len(p) >= 5 and p[-1] in set(order):
        ints = [tok for tok in p[:-1] if tok.lstrip("-").isdigit()]
        if len(ints) >= 3:
            u, ca, i = int(ints[0]), int(ints[1]), int(ints[2])
            stats[p[-1]] = (u, ca, i)

tu = tc = ti = 0
print("**Table 1: Benchmark programs**\n")
print("| Name | C LOC | Rust LOC | #Unions | #Candidates | #Identified |")
print("| --- | --- | --- | --- | --- | --- |")

for n in order:
    c, r = loc.get(n, ("", ""))
    u, ca, i = stats.get(n, ("", "", ""))
    if u != "":
        tu += u
        tc += ca
        ti += i
    print(f"| {disp.get(n, n)} | {c} | {r} | {u} | {ca} | {i} |")

print(f"| Total |  |  | {tu} | {tc} | {ti} |")
print()  # ensure trailing newline
PY
echo '</artisan_submit>'
