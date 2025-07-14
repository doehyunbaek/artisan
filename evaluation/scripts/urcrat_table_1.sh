#!/usr/bin/env sh

set -e
docker rm -f urcrat 2>/dev/null || true
docker run -d --name urcrat --entrypoint /bin/sh artisan25/urcrat -c "sleep infinity"

docker exec urcrat sh -c 'start.sh'
docker exec urcrat sh -c 'size.sh'
docker exec urcrat sh -c 'run.sh'