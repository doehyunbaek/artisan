#!/usr/bin/env sh

set -e
docker rm -f pythonic 2>/dev/null || true
docker run -d --name pythonic --entrypoint /bin/sh artisan25/pythonic -c "sleep infinity"

docker exec pythonic sh -c 'cd /data && R --no-save < /data/FuncConstructs-Statistics.r'
