#!/usr/bin/env sh

docker run --rm --mount "type=bind,source=.,target=/analysis-output" artisan25/scout