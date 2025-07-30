# Artisan: An Agentic Approach for Artifact Evaluation

## Installation

Artisan uses three kinds of Docker containers:

* A Visual Studio Code Dev Container for running Testora itself. See [devcontainer.json](.devcontainer/devcontainer.json).

* Docker-outside-docker containers for running OpenHands docker runtime.

* Docker containers for running the docker images for research artifacts.

To install and run Testora, follow these steps:

1) Install [Visual Studio Code](https://code.visualstudio.com/download) and its ["Dev Containers" extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers).

2) Open artisan in Visual Studio Code:
   
   ```code .```

3) In Visual Studio Code, build the Dev Container and reopen the project in the container:

    ```Ctrl + Shift + P```

    ```Dev Containers: Rebuild and Reopen in Container```

4) Set up the api key for LLMS by setting API_KEY environment variable to the api provider of your choice.

## Running Artisan

```sh
python evaluation/run_experiment.py pythonic
```

