#!/usr/bin/env sh

set -e
docker rm -f lasapp 2>/dev/null || true
docker run -d --name lasapp artisan25/lasapp sleep infinity

docker exec -it lasapp sh -c '/LASAPP/scripts/start_servers.sh'
sleep 10
docker exec -it lasapp sh -c 'python3 /LASAPP/experiments/evaluate_graph_and_constraints.py -ppl turing'
docker exec -it lasapp sh -c 'python3 /LASAPP/experiments/evaluate_graph_and_constraints.py -ppl pymc'
docker exec -it lasapp sh -c 'python3 /LASAPP/experiments/evaluate_hmc.py'
docker exec -it lasapp sh -c 'python3 /LASAPP/experiments/evaluate_guide.py'
