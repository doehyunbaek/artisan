#!/bin/bash

# Pull the Docker image
sudo docker pull artisan25/urcrat

# Run the experiments
sudo docker run --rm artisan25/urcrat run_experiments.sh

# Parse the results
sudo docker run --rm artisan25/urcrat parse_results.sh

# Find and aggregate results
sudo docker run --rm artisan25/urcrat find_results.sh
sudo docker run --rm artisan25/urcrat aggregate_results.sh

# Show the results
sudo docker run --rm artisan25/urcrat show_results.sh

# Finalize and output results
sudo docker run --rm artisan25/urcrat finalize_results.sh
sudo docker run --rm artisan25/urcrat output_results.sh
