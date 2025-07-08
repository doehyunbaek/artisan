#!/usr/bin/env sh

set -e
docker rm -f scout 2>/dev/null || true
docker run -d --name scout artisan25/scout sleep infinity

docker exec -it scout R -e "rmarkdown::render('/analysis-source/scout_results.Rmd', output_file='/analysis-output/scout_results.pdf')"
