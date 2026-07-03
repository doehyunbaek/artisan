#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 3: Evaluation Results**

| Project Name          | Summary                                                                                | Annotations | Total Warnings |
| --------------------- | -------------------------------------------------------------------------------------- | ----------: | -------------: |
| MarginSwap            | Dex project for margin trading on Uniswap and Sushiswap                                |           6 |              1 |
| Vader Protocol        | Yield project for a collateralized stablecoin                                          |          17 |              4 |
| PoolTogether          | Gaming service on yield interest                                                       |          15 |              1 |
| Tracer                | Derivative project that supports perpetual markets                                     |          10 |              1 |
| Yield Micro           | Lending project supporting borrowing, lending, and liquidity                           |           4 |              1 |
| Sushi Trident         | Dex project for deploying personalized liquidity markets                               |          24 |              0 |
| yAxis                 | Yield project where users’ aggregated funds are used in strategies for yield           |           9 |              4 |
| Badger Dao            | Yield project                                                                          |           9 |              2 |
| Wild Credit           | Lending project relying on pairs of assets instead of a pool                           |          17 |              4 |
| PoolTogether v4       | Gaming service on yield interest                                                       |           1 |              0 |
| Sushi Trident p2      | Dex project for deploying personalized liquidity markets                               |          12 |             10 |
| Swell                 | Yield project that uses set orders for Yield claiming                                  |           5 |              2 |
| Covalent              | Users delegate commissions to a Validators, which stakes the funds for interest        |           6 |              1 |
| yAxis p2              | Yield project where users’ aggregated funds are used in strategies for yield           |           2 |              0 |
| Perennial             | Derivative project supporting synthetic token perpetual markets                        |           3 |              2 |
| Yeti Finance          | Lending project made against a contract specific token                                 |           9 |              0 |
| Vader Protocol p3     | Yield project for a collateralized stablecoin                                          |           5 |              4 |
| InsureDao             | Insurance markets where buyers pay premium for protection against losses               |          11 |              0 |
| Rocket Joe            | Dex project where users exchange funds in return for new project liquidity             |           7 |              3 |
| Concur Finance        | Yield project                                                                          |           4 |              0 |
| Biconomy Hyphen       | Cross Chain project where users can deposit and withdraw for pools on different chains |           6 |              1 |
| Volt                  | Dex project which conserves the value of user funds against inflation                  |           1 |              0 |
| Badger Dao p3         | Yield project                                                                          |           8 |              0 |
| Tigris Trade          | Dex project utilizing off-chain oracles to provide real-time prices                    |          11 |              2 |
| **Total**             |                                                                                        |             |             43 |

EOTABLE

# Section 2: Artifact download
curl -L -o /workspace/ScType-publish_onto_zenodo.zip "https://zenodo.org/records/10449162/files/NioTheFirst/ScType-publish_onto_zenodo.zip?download=1" || true

# Section 3: Reproduction commands (populate from reviewed steps)
# Pull the Docker image, (re)create the container, and run the provided benchmark script.
docker pull icse24sctype/full:latest || true
docker rm -f sctype_repro 2>/dev/null || true
docker run -d --init --entrypoint bash --name sctype_repro icse24sctype/full:latest -c 'sleep infinity'
# Give the container a moment to initialize
sleep 5
# Execute the benchmark script inside the container and capture output to the host workspace
docker exec sctype_repro /bin/bash --noprofile --norc -c "/home/slither/slither/test_benchmark_final.sh" > /workspace/repro.txt 2>&1 || true

# Section 4: Formatting and submission block
echo '<artisan_submit>'
# Output the captured reproduction results
cat /workspace/repro.txt || echo "No reproduction output captured."
echo '</artisan_submit>'
