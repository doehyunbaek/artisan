#!/usr/bin/env sh

set -e
docker rm -f sctype 2>/dev/null || true
docker run -d --name sctype artisan25/sctype sleep infinity

docker exec -it sctype sh -c '/home/slither/slither/test_benchmark_final.sh'
