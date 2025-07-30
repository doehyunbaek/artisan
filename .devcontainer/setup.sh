#!/bin/bash

pip install -r requirements.txt
git config --global --add safe.directory '*' && git submodule update --init --recursive
cd ./third_party/OpenHands && make build