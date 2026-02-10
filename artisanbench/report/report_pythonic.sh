docker run -i --rm --privileged -w /workspace doehyunbaek1/dind bash << 'EOF'
#!/usr/bin/bash

# 1. Download and Extract
curl -L -o ICSE2024-funcConstructs-Artifacts.zip "https://zenodo.org/records/10554377/files/ICSE2024-funcConstructs-Artifacts.zip?download=1"
unzip ICSE2024-funcConstructs-Artifacts.zip > /dev/null

docker pull mdipenta/rexp:latest
docker run -d --init --entrypoint bash -v"${PWD}":/data --name shell mdipenta/rexp:latest -c 'sleep infinity'
docker exec shell /bin/bash --noprofile --norc -c "cd /data/ICSE2024-funcConstructs-Artifacts/ && R --no-save < FuncConstructs-Statistics.r"
cat /workspace/ICSE2024-funcConstructs-Artifacts/results/Table-3-RQ1-lambda.txt > /workspace/repro.txt
cat /workspace/repro.txt
EOF