#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 3: Evaluation Results**

| Project Name          | Summary                                                                                | Annotations | Total Warnings |
| --------------------- | -------------------------------------------------------------------------------------- | ----------: | -------------: |
| MarginSwap            | Dex project for margin trading on Uniswap and Sushiswap                                |           ? |              ? |
| Vader Protocol        | Yield project for a collateralized stablecoin                                          |          ?? |              ? |
| PoolTogether          | Gaming service on yield interest                                                       |          ?? |              ? |
| Tracer                | Derivative project that supports perpetual markets                                     |          ?? |              ? |
| Yield Micro           | Lending project supporting borrowing, lending, and liquidity                           |           ? |              ? |
| Sushi Trident         | Dex project for deploying personalized liquidity markets                               |          ?? |              ? |
| yAxis                 | Yield project where users’ aggregated funds are used in strategies for yield           |           ? |              ? |
| Badger Dao            | Yield project                                                                          |           ? |              ? |
| Wild Credit           | Lending project relying on pairs of assets instead of a pool                           |          ?? |              ? |
| PoolTogether v4       | Gaming service on yield interest                                                       |           ? |              ? |
| Sushi Trident p2      | Dex project for deploying personalized liquidity markets                               |          ?? |             ?? |
| Swell                 | Yield project that uses set orders for Yield claiming                                  |           ? |              ? |
| Covalent              | Users delegate commissions to a Validators, which stakes the funds for interest        |           ? |              ? |
| yAxis p2              | Yield project where users’ aggregated funds are used in strategies for yield           |           ? |              ? |
| Perennial             | Derivative project supporting synthetic token perpetual markets                        |           ? |              ? |
| Yeti Finance          | Lending project made against a contract specific token                                 |           ? |              ? |
| Vader Protocol p3     | Yield project for a collateralized stablecoin                                          |           ? |              ? |
| InsureDao             | Insurance markets where buyers pay premium for protection against losses               |          ?? |              ? |
| Rocket Joe            | Dex project where users exchange funds in return for new project liquidity             |           ? |              ? |
| Concur Finance        | Yield project                                                                          |           ? |              ? |
| Biconomy Hyphen       | Cross Chain project where users can deposit and withdraw for pools on different chains |           ? |              ? |
| Volt                  | Dex project which conserves the value of user funds against inflation                  |           ? |              ? |
| Badger Dao p3         | Yield project                                                                          |           ? |              ? |
| Tigris Trade          | Dex project utilizing off-chain oracles to provide real-time prices                    |          ?? |              ? |
| **Total**             |                                                                                        |             |             ?? |

EOTABLE
# Section 2: Artifact download
artisan get https://zenodo.org/records/10449162
# Section 3: Reproduction commands (populate from reviewed steps)
# Pull docker image (prefer pull first)
docker pull icse24sctype/full:latest
# Ensure any previous container by this name is removed
docker rm -f sctype_repro || true
# Run container in detached sleep mode so we can exec into it
docker run -d --init --entrypoint bash --name sctype_repro icse24sctype/full:latest -c 'sleep infinity'
# Execute the benchmark script inside the container, capture stdout/stderr to /tmp/repro.txt inside the container
docker exec sctype_repro /bin/bash --noprofile --norc -c "./test_benchmark_final.sh > /tmp/repro.txt 2>&1"
# Copy the produced output to the host workspace for formatting/inspection
docker cp sctype_repro:/tmp/repro.txt /workspace/repro.txt || true
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
