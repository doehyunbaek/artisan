#!/bin/bash

# Start language servers
./scripts/start_servers.sh

# Run evaluations
python3 experiments/evaluate_graph_and_constraints.py -ppl turing
python3 experiments/evaluate_graph_and_constraints.py -ppl pymc
python3 experiments/evaluate_hmc.py
python3 experiments/evaluate_guide.py

# Stop language servers
./scripts/stop_servers.sh


# Start language servers
./scripts/start_servers.sh

# Run evaluations
python3 experiments/evaluate_graph_and_constraints.py -ppl turing
python3 experiments/evaluate_graph_and_constraints.py -ppl pymc
python3 experiments/evaluate_hmc.py
python3 experiments/evaluate_guide.py

# Stop language servers
./scripts/stop_servers.sh
