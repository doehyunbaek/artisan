#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 2: Summary tables of evaluation results.**

| Analysis               | PPL    | Total Programs | Warnings produced  |
| ---------------------- | ------ | -------------: | ----------------:  |
| Dependency Analysis    | Turing |            117 |                 6  |
| Dependency Analysis    | PyMC   |             97 |                 2  |
| Constraint Verifier    | Turing |            117 |                 37 |
| Constraint Verifier    | PyMC   |             97 |                 32 |
| HMC Assumption Checker | Gen    |              8 |                 7  |
| Model-Guide Validator  | Pyro   |              8 |                 2  |

EOTABLE

# Section 2: Artifact download
# Download the lasapp-main zip and docker image tar from Zenodo
curl -L -o /workspace/lasapp-main.zip "https://zenodo.org/api/records/15857114/files/lasapp-main.zip/content"
# The docker image archive is large (~500MB). Uncomment to download if you have sufficient bandwidth/time.
# curl -L -o /workspace/lasapp-amd64.tar "https://zenodo.org/api/records/15857114/files/lasapp-amd64.tar/content"

# Section 3: Reproduction commands (populate from reviewed steps)
# NOTE: The full reproduced experiments require Docker and the pre-built docker image.
# The script below assumes docker is available and that you downloaded lasapp-amd64.tar.
# It will load the docker image, start a container with the workspace mounted, start servers,
# run the evaluation scripts, collect outputs in /workspace/repro.txt and then stop the container.

# Extract the lasapp-main.zip locally (this is small and contains sources)
unzip -o /workspace/lasapp-main.zip -d /workspace || true

# Check for docker and load image
if command -v docker > /dev/null 2>&1; then
    echo "Docker found"
    if [ -f /workspace/lasapp-amd64.tar ]; then
        echo "Loading docker image from lasapp-amd64.tar (may take a while)"
        docker load -i /workspace/lasapp-amd64.tar
        IMAGE_NAME=$(docker images --format '{{.Repository}}:{{.Tag}}' | grep lasapp || true)
        if [ -z "$IMAGE_NAME" ]; then
            # fallback
            IMAGE_NAME=lasapp-amd64
        fi
        # run container detached with workspace mounted
        docker run -d --init --entrypoint bash --name lasapp_container -v /workspace/lasapp-main/lasapp-main:/LASAPP -v /workspace:/workspace $IMAGE_NAME -c 'sleep infinity'
        CONTAINER_ID=$(docker ps -qf "name=lasapp_container")
        echo "Started container: $CONTAINER_ID"

        # Start language servers inside the container (uses tmux inside image)
        docker exec $CONTAINER_ID /bin/bash --noprofile --norc -c "cd /LASAPP && ./scripts/start_servers.sh"
        sleep 3

        # Run evaluations inside container and redirect outputs back to mounted /workspace
        docker exec $CONTAINER_ID /bin/bash --noprofile --norc -c "cd /LASAPP && python3 experiments/evaluate_graph_and_constraints.py -ppl turing -analysis both" > /workspace/repro_turing.txt 2>&1 || true
        docker exec $CONTAINER_ID /bin/bash --noprofile --norc -c "cd /LASAPP && python3 experiments/evaluate_graph_and_constraints.py -ppl pymc -analysis both" > /workspace/repro_pymc.txt 2>&1 || true
        docker exec $CONTAINER_ID /bin/bash --noprofile --norc -c "cd /LASAPP && python3 experiments/evaluate_hmc.py" > /workspace/repro_gen.txt 2>&1 || true
        docker exec $CONTAINER_ID /bin/bash --noprofile --norc -c "cd /LASAPP && python3 experiments/evaluate_guide.py" > /workspace/repro_pyro.txt 2>&1 || true

        # Aggregate results to /workspace/repro.txt in a simple summary form
        echo "--- Turing (graph+constraint) ---" > /workspace/repro.txt
        tail -n 50 /workspace/repro_turing.txt >> /workspace/repro.txt || true
        echo "\n--- PyMC (graph+constraint) ---" >> /workspace/repro.txt
        tail -n 50 /workspace/repro_pymc.txt >> /workspace/repro.txt || true
        echo "\n--- Gen (HMC) ---" >> /workspace/repro.txt
        tail -n 50 /workspace/repro_gen.txt >> /workspace/repro.txt || true
        echo "\n--- Pyro (Guide) ---" >> /workspace/repro.txt
        tail -n 50 /workspace/repro_pyro.txt >> /workspace/repro.txt || true

        # Stop servers and remove container
        docker exec $CONTAINER_ID /bin/bash --noprofile --norc -c "cd /LASAPP && ./scripts/stop_servers.sh" || true
        docker rm -f $CONTAINER_ID || true
    else
        echo "Docker image tar not found at /workspace/lasapp-amd64.tar. Please download it from Zenodo and re-run."
    fi
else
    echo "Docker is not installed on this host. Cannot run full reproduction here."
    echo "You can run the following commands on a machine with Docker available after downloading lasapp-amd64.tar:"
    echo "  docker load -i lasapp-amd64.tar"
    echo "  docker run -d --init --entrypoint bash --name lasapp_container -v \\$(pwd)/lasapp-main:/LASAPP -v \\$(pwd):/workspace lasapp-amd64 -c 'sleep infinity'"
    echo "  docker exec lasapp_container /bin/bash --noprofile --norc -c 'cd /LASAPP && ./scripts/start_servers.sh'"
    echo "  docker exec lasapp_container /bin/bash --noprofile --norc -c 'cd /LASAPP && python3 experiments/evaluate_graph_and_constraints.py -ppl turing -analysis both' > repro_turing.txt"
    echo "  docker exec lasapp_container /bin/bash --noprofile --norc -c 'cd /LASAPP && python3 experiments/evaluate_graph_and_constraints.py -ppl pymc -analysis both' > repro_pymc.txt"
    echo "  docker exec lasapp_container /bin/bash --noprofile --norc -c 'cd /LASAPP && python3 experiments/evaluate_hmc.py' > repro_gen.txt"
    echo "  docker exec lasapp_container /bin/bash --noprofile --norc -c 'cd /LASAPP && python3 experiments/evaluate_guide.py' > repro_pyro.txt"
    echo "  docker exec lasapp_container /bin/bash --noprofile --norc -c 'cd /LASAPP && ./scripts/stop_servers.sh'"
fi

# Section 4: Formatting and submission block
echo '<artisan_submit>'
# Print the aggregated repro.txt if present
if [ -f /workspace/repro.txt ]; then
    cat /workspace/repro.txt
else
    echo "No reproduction output found. Please run this script on a system with Docker."
fi
echo '</artisan_submit>'
