# Artisan: An Agentic Approach for Artifact Evaluation

## Setup

- Clone the repository and submodules

```sh
git clone --recursive https://github.com/doehyunbaek/artisan
# or git clone https://github.com/doehyunbaek/artisan; git submodule update --init
```

- Install dependencies

```sh
pip install -r requirements.txt
# consult third_party/OpenHands/Development.md to install the required dependencies.
```

- Build OpenHands

```sh
cd third_party/OpenHands/
make build
```

- Run experiments

```sh
python evaluation/run_experiment.py
```

- (Optional) Update OpenHands config

```sh
code evaluation/openhands_config.toml
```
