docker run -i --rm --privileged -w /workspace doehyunbaek1/dind bash << 'EOF'
#!/usr/bin/bash
docker pull kaistplrg/urcrat:ase2024
docker run -d --init --entrypoint bash --name urcrat_ase kaistplrg/urcrat:ase2024 -c 'sleep infinity'
docker exec urcrat_ase /bin/bash --noprofile --norc -c "size.sh" > /workspace/repro.txt

EOF
