docker run -i --rm --privileged -w /workspace doehyunbaek1/dind bash << 'EOF'
#!/usr/bin/bash

# 1. Download and Extract
curl -L -o Cargo-Ecosystem-Monitor-ICSE.zip "https://zenodo.org/records/10496086/files/Cargo-Ecosystem-Monitor-ICSE.zip?download=1"
unzip Cargo-Ecosystem-Monitor-ICSE.zip > /dev/null

docker build -t cargo-ecosystem-monitor /workspace/Cargo-Ecosystem-Monitor
docker run -d --init --entrypoint /bin/bash --name cargo_ecosystem_monitor_run -e POSTGRES_PASSWORD="postgres" -w /app --mount type=bind,src="/workspace",target=/app cargo-ecosystem-monitor -c 'sleep infinity'
docker exec cargo_ecosystem_monitor_run /bin/bash --noprofile --norc -c 'cd /app/Cargo-Ecosystem-Monitor/Code/accuracy_evaluation && python3 -m zipfile -e EDG_Evaluation_20220811.zip . && cargo run --bin summary_release > /app/repro.txt 2>&1'

cat /workspace/repro.txt
EOF