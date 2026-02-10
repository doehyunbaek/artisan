docker run -i --rm --privileged -w /workspace doehyunbaek1/dind bash << 'EOF'
#!/usr/bin/bash
curl -L -o axa-artifact-image.tar "https://zenodo.org/records/13374578/files/axa-artifact-image.tar?download=1"
docker load -i axa-artifact-image.tar
docker run -d --init --name axa_container --entrypoint bash axaimage -c 'sleep infinity'

# Fix the stray '+' in the printLOCs.sh inside the container (if present)
docker exec axa_container /bin/bash --noprofile --norc -c "python3 - <<'PY'
fn='/runner/printLOCs.sh'
s=open(fn).read()
s=s.replace(') +',')')
open(fn,'w').write(s)
print('edited')
PY"

docker exec axa_container /bin/bash --noprofile --norc -c "/runner/printLOCs.sh" > /workspace/repro.txt
cat /workspace/repro.txt

EOF
