docker run -i --rm --privileged -w /workspace doehyunbaek1/dind bash << 'EOF'
#!/usr/bin/bash
docker pull icse24sctype/full:latest
docker run -d --name sctype --entrypoint /bin/sh icse24sctype/full:latest -c "sleep infinity"
docker exec sctype sh -c './test_benchmark_final.sh' > /workspace/repro.txt
cat /workspace/repro.txt

EOF
