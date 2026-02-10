import logging
import os
import shutil
import json
import yaml
import docker
import time
import socket
import threading
from pathlib import Path
from jinja2 import Template

from openhands.sdk import LLM, Agent, Conversation, Tool
from openhands.tools.terminal import TerminalTool
from openhands.sdk.workspace import RemoteWorkspace
from openhands.workspace import DockerWorkspace
from openhands.tools.preset.default import get_default_agent
from openhands.sdk.utils.command import execute_command
from pydantic import Field
import uuid

# Monkeypatch to fix Validation Error from version mismatch (extra fields from server)
try:
    from openhands.sdk.event.llm_convertible.action import ActionEvent
    # Relax validation for ActionEvent to allow 'summary' and other extra fields
    ActionEvent.model_config["extra"] = "ignore"
    ActionEvent.model_rebuild(force=True)
except ImportError:
    pass

import artisan
from artisan import util

logger = logging.getLogger("artisan.agents.openhands")

def check_port_available(port: int) -> bool:
    """Check if a port is available for binding."""
    import socket

    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    try:
        sock.bind(("0.0.0.0", port))
        return True
    except OSError:
        time.sleep(0.1)
        return False
    finally:
        sock.close()

def find_available_tcp_port(
    min_port: int = 30000, max_port: int = 39999, max_attempts: int = 50
) -> int:
    """Find an available TCP port in a specified range."""
    import random

    rng = random.SystemRandom()
    ports = list(range(min_port, max_port + 1))
    rng.shuffle(ports)

    for port in ports[:max_attempts]:
        if check_port_available(port):
            return port
    return -1

class ArtisanDockerWorkspace(DockerWorkspace):
    """
    Extensions to the standard OpenHands DockerWorkspace to support:
    - Custom command injection (for installing the server on bare images)
    - Privileged mode
    - Group Add
    """
    privileged: bool = Field(default=False, description="Run container in privileged mode")
    group_add: list[str] = Field(default_factory=list, description="List of additional groups to join")
    command: str | None = Field(default=None, description="Custom command override")
    env_vars: dict[str, str] = Field(default_factory=dict, description="Environment variables to set")
    platform: str | None = Field(default=None, description="Platform (e.g. linux/amd64)")

    def _start_container(self, image: str, context: object) -> None:
        """Start the Docker container with custom configs."""
        # Store the image name for cleanup
        self._image_name = image

        # Determine port
        if self.host_port is None:
            self.host_port = find_available_tcp_port()
        else:
            self.host_port = int(self.host_port)

        if not check_port_available(self.host_port):
            raise RuntimeError(f"Port {self.host_port} is not available")

        # Ensure docker is available
        docker_ver = execute_command(["docker", "version"]).returncode
        if docker_ver != 0:
            raise RuntimeError(
                "Docker is not available. Please install and start "
                "Docker Desktop/daemon."
            )

        # Prepare Docker run flags
        flags: list[str] = []
        for key in self.forward_env:
            if key in os.environ:
                flags += ["-e", f"{key}={os.environ[key]}"]

        for k, v in self.env_vars.items():
            flags += ["-e", f"{k}={v}"]

        for volume in self.volumes:
            flags += ["-v", volume]
            logger.info(f"Adding volume mount: {volume}")

        ports = ["-p", f"{self.host_port}:8000"]
        if self.extra_ports:
            ports += [
                "-p",
                f"{self.host_port + 1}:8001",  # VSCode
                "-p",
                f"{self.host_port + 2}:8002",  # Desktop VNC
            ]
        flags += ports

        # Add GPU support if enabled
        if self.enable_gpu:
            flags += ["--gpus", "all"]

        # Custom flags
        if self.privileged:
            flags += ["--privileged"]

        for grp in self.group_add:
            flags += ["--group-add", grp]

        run_cmd_args = [
            "docker",
            "run",
            "-d",
            "--rm",
            "--name",
            f"agent-server-{uuid.uuid4()}",
            *flags,
        ]

        if self.platform:
              run_cmd_args += ["--platform", self.platform]

        run_cmd_args.append(image)

        if self.command:
            run_cmd_args += ["bash", "-c", self.command]
        else:
             run_cmd_args += ["--host", "0.0.0.0", "--port", "8000"]

        proc = execute_command(run_cmd_args)
        if proc.returncode != 0:
            raise RuntimeError(f"Failed to run docker container: {proc.stderr}")

        self._container_id = proc.stdout.strip()
        logger.info(f"Started container: {self._container_id}")

        # Optionally stream logs in background
        if self.detach_logs:
            self._logs_thread = threading.Thread(
                target=self._stream_docker_logs, daemon=True
            )
            self._logs_thread.start()

        # Set host for RemoteWorkspace to use
        object.__setattr__(self, "host", f"http://localhost:{self.host_port}")
        object.__setattr__(self, "api_key", None)

        # Wait for container to be healthy
        self._wait_for_health()
        logger.info(f"Docker workspace is ready at {self.host}")

        RemoteWorkspace.model_post_init(self, context)

    def _wait_for_health(self):
        host_url = self.host
        import requests
        wait_time = 300 # Give more time for custom installs
        for i in range(wait_time):
            try:
                if requests.get(f"{host_url}/alive").status_code == 200:
                     return
            except:
                pass
            time.sleep(1)

        # Capture logs heavily if it fails
        logs = "Could not retrieve logs"
        try:
            res = execute_command(["docker", "logs", "--tail", "50", self._container_id])
            logs = res.stdout + res.stderr
        except Exception as e:
            logs = f"Failed to get logs: {e}"

        raise RuntimeError(f"Agent server failed to start at {host_url}. Logs:\n{logs}")

def setup_workspace(
    paper: str,
    workspace_dir: str,
    paper_path: str,
    expected_table: str,
    env_kwargs: dict,
) -> tuple[dict, str]:
    """Prepare a local workspace directory for mounting into the Docker environment."""
    ws_path = Path(workspace_dir).expanduser().resolve()
    ws_path.mkdir(parents=True, exist_ok=True)

    (ws_path / "expected.md").write_text(expected_table, encoding="utf-8")

    dest = ws_path / "paper.md"
    shutil.copy2(paper_path, dest)

    return env_kwargs, None

def save_traj(conversation, path, exit_status, result, llm=None):
    # Convert OpenHands history to Artisan/MiniSWEAgent format
    # This is a best-effort conversion
    messages = []

    # Try to get events
    events = []
    if hasattr(conversation, 'events'):
        events = list(conversation.events)
    elif hasattr(conversation, 'state') and hasattr(conversation.state, 'events'):
        events = list(conversation.state.events)

    for event in events:
        messages.append({
            "event_type": type(event).__name__,
            "data": event.model_dump(mode="json")
        })

    # Extract model stats
    model_stats = {}
    metrics_found = False

    # 1. Try to get stats from usage_to_metrics (most accurate for OpenHands)
    try:
        state = getattr(conversation, "state", None)
        stats = getattr(state, "stats", None) if state else None

        usage_to_metrics = None
        if stats:
            if isinstance(stats, dict):
                usage_to_metrics = stats.get("usage_to_metrics")
            elif hasattr(stats, "usage_to_metrics"):
                usage_to_metrics = stats.usage_to_metrics

        if usage_to_metrics:
            total_cost = 0.0

            # Normalize to dict items
            if hasattr(usage_to_metrics, "model_dump"):
                metrics_iter = usage_to_metrics.model_dump().items()
            elif isinstance(usage_to_metrics, dict):
                metrics_iter = usage_to_metrics.items()
            elif hasattr(usage_to_metrics, "__dict__"):
                metrics_iter = usage_to_metrics.__dict__.items()
            else:
                metrics_iter = []

            for key, m in metrics_iter:
                if isinstance(m, dict):
                    total_cost += m.get("accumulated_cost", 0.0) or 0.0
                elif hasattr(m, "accumulated_cost"):
                    total_cost += m.accumulated_cost or 0.0

            model_stats["total_cost"] = total_cost
            model_stats["instance_cost"] = total_cost
            metrics_found = True

            # Try to populate tokens from 'default'
            default_m = None
            if hasattr(usage_to_metrics, "get"):
                default_m = usage_to_metrics.get("default")
            elif hasattr(usage_to_metrics, "default"):
                default_m = usage_to_metrics.default

            if default_m:
                tk = None
                if isinstance(default_m, dict):
                    tk = default_m.get("accumulated_token_usage")
                elif hasattr(default_m, "accumulated_token_usage"):
                    tk = default_m.accumulated_token_usage

                if tk:
                    if hasattr(tk, "model_dump"):
                        model_stats["tokens"] = tk.model_dump(mode="json")
                    elif hasattr(tk, "__dict__"):
                        model_stats["tokens"] = vars(tk)
                    else:
                        model_stats["tokens"] = tk
    except Exception as e:
        logger.warning(f"Failed to calculate cost from usage_to_metrics: {e}")

    if not metrics_found:
        if llm and hasattr(llm, "metrics"):
            try:
                metrics = llm.metrics
                if metrics:
                    model_stats["total_cost"] = metrics.accumulated_cost
                    model_stats["instance_cost"] = metrics.accumulated_cost
                    if metrics.accumulated_token_usage:
                        if hasattr(metrics.accumulated_token_usage, "model_dump"):
                            model_stats["tokens"] = metrics.accumulated_token_usage.model_dump(mode="json")
                        elif hasattr(metrics.accumulated_token_usage, "__dict__"):
                            model_stats["tokens"] = vars(metrics.accumulated_token_usage)
                        else:
                            model_stats["tokens"] = metrics.accumulated_token_usage
            except Exception as e:
                logger.warning(f"Failed to extract model stats from llm: {e}")
        else:
            # Try to find llm in conversation if not provided
            try:
                if hasattr(conversation, "agent") and hasattr(conversation.agent, "llm"):
                    metrics = conversation.agent.llm.metrics
                    if metrics:
                        model_stats["total_cost"] = metrics.accumulated_cost
                        model_stats["instance_cost"] = metrics.accumulated_cost
                        if metrics.accumulated_token_usage:
                            if hasattr(metrics.accumulated_token_usage, "model_dump"):
                                model_stats["tokens"] = metrics.accumulated_token_usage.model_dump(mode="json")
                            elif hasattr(metrics.accumulated_token_usage, "__dict__"):
                                model_stats["tokens"] = vars(metrics.accumulated_token_usage)
                            else:
                                model_stats["tokens"] = metrics.accumulated_token_usage
            except Exception as e:
                pass

    data = {
        "info": {
            "exit_status": exit_status,
            "submission": result,
            "model_stats": model_stats,
            "execution_status": str(getattr(conversation, "execution_status", "unknown")),
        },
        "messages": messages,
        "trajectory_format": "openhands-1",
    }

    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2))
    logger.info(f"Saved trajectory to '{path}'")

def run_with_openhands(
    workspace_dir: str,
    table_path: str,
    paper_path: str,
    artifact_url: str,
    interactive: bool,
    model_name: str | None = None,
    prompt_path: str | None = None,
):
    """Run OpenHands agent with the provided prompt."""
    repo_root = Path(util.find_repo_root())
    artifact_name = util.table_to_artifact(table_path)
    table_index = util.table_to_index(table_path)
    paper = util.table_to_paper(table_path)
    expected_table = util.get_original_table(paper, table_index)

    # 1. Setup Files
    env_kwargs = {}
    setup_workspace(paper, workspace_dir, paper_path, expected_table, env_kwargs)

    # 2. Config
    if prompt_path:
        config_path = Path(prompt_path)
    else:
        config_path = repo_root / "evaluation" / "prompts" / "minisweagent.yaml"

    with config_path.open("r", encoding="utf-8") as fh:
        config = yaml.safe_load(fh)

    # 3. Prepare Prompt
    # We strip the specific <mini_swe_agent_bash> format requirements as OpenHands uses tools
    # But we MUST keep the logic about downloading artifact and submitting.
    instance_template = config["agent"]["instance_template"]

    prompt = Template(instance_template).render(
        artifact_url=artifact_url,
        table_index=table_index,
        expected_table=expected_table,
        artifact_name=artifact_name,
        table_path=table_path
    )

    # 4. Initialize OpenHands
    # Detect API Key
    api_key = os.getenv("LLM_API_KEY")

    # Extract configs
    agent_config = config.get("agent", {})
    step_limit = int(float(agent_config.get("step_limit", 30)))
    cost_limit = float(agent_config.get("cost_limit", 0))

    env_config = config.get("environment", {})
    env_vars = env_config.get("env", {})
    env_timeout = int(env_config.get("timeout", 28800)) # Default 8h

    model_config_section = config.get("model", {})
    model_kwargs = model_config_section.get("model_kwargs", {})

    # Heuristics for API Keys based on model name
    llm_model = model_name or model_config_section.get("model_name", "gpt-4o")

    if llm_model == "deepseek":
        llm_model = "deepseek/deepseek-chat"
    elif llm_model == "gpt5.1":
        llm_model = "gpt-5.1"
    elif llm_model == "gpt5mini":
        llm_model = "gpt-5-mini"

    if not api_key:
        if "deepseek" in llm_model.lower():
            api_key = os.getenv("DEEPSEEK_API_KEY")
        elif "claude" in llm_model.lower():
            api_key = os.getenv("ANTHROPIC_API_KEY")
        elif "gpt" in llm_model.lower():
            api_key = os.getenv("OPENAI_API_KEY")

    # Fallback
    if not api_key:
        api_key = os.getenv("OPENAI_API_KEY") or os.getenv("DEEPSEEK_API_KEY") or os.getenv("ANTHROPIC_API_KEY")

    if not api_key:
        logger.warning("No API KEY found (checked LLM_API_KEY, OPENAI_API_KEY, DEEPSEEK_API_KEY, ANTHROPIC_API_KEY)")

    # Prepare LLM config
    # Merge model_kwargs into config
    logger.info(f"Initializing LLM with model_kwargs: {model_kwargs}")
    llm = LLM(
        model=llm_model,
        api_key=api_key,
        **model_kwargs
    )

    # Use DockerWorkspace
    # We need to ensure we can access the workspace files.
    # Since OpenHands DockerWorkspace might not support generic mounts easily,
    # we copy the files into the workspace after startup if needed, OR
    # we assume the user runs this script in a way that maps it.
    # For now, we will rely on `DockerWorkspace` default behavior and try to `cp` files.

    logger.info(f"Starting OpenHands Agent with model {llm_model} (step_limit={step_limit}, timeout={env_timeout}s)")

    # Platform detection
    import platform
    machine = platform.machine().lower()
    plat = "linux/arm64" if "arm" in machine or "aarch64" in machine else "linux/amd64"

    # Docker/Environment Setup logic from minisweagent
    volumes = {}
    group_add = []

    # MITM
    if artisan.ARTISAN_MITM_URL:
        env_vars["ARTISAN_MITM_URL"] = artisan.ARTISAN_MITM_URL

    # Pass Keys if found
    if api_key:
        env_vars["OPENAI_API_KEY"] = api_key # Most tools expect this? Or we should pass all
    if os.getenv("DEEPSEEK_API_KEY"):
        env_vars["DEEPSEEK_API_KEY"] = os.getenv("DEEPSEEK_API_KEY")
    if os.getenv("ANTHROPIC_API_KEY"):
        env_vars["ANTHROPIC_API_KEY"] = os.getenv("ANTHROPIC_API_KEY")

    # Determine image
    # Use artisan.BASE_IMAGE to match minisweagent environment
    # But we need to install openhands-ai in it if we use it.
    target_image = artisan.BASE_IMAGE

    command = None
    is_openhands_image = "openhands/agent-server" in target_image
    if not is_openhands_image:
        install_cmd = (
             "nohup dockerd > /tmp/dockerd.log 2>&1 & "
             "while ! docker info >/dev/null 2>&1; do sleep 1; done && "
             "pip install --upgrade pip && "
             "pip install openhands-ai && "
             "export PORT=8000 && "
             "python -m openhands.agent_server"
        )
        command = f"bash -c '{install_cmd}'"

    # Convert volumes to list of strings
    volume_list = []
    for k, v in volumes.items():
        mode = v.get("mode", "rw")
        bind = v.get("bind", k)
        volume_list.append(f"{k}:{bind}:{mode}")

    # Initialize workspace
    workspace = ArtisanDockerWorkspace(
        server_image=target_image,
        platform=plat,
        host_port=None,
        env_vars=env_vars,
        volumes=volume_list,
        privileged=True,
        group_add=group_add,
        command=command
    )

    with workspace:

        # ... copy files ...

        # Copy files to workspace
        # DockerWorkspace manages a container. We can execute commands.
        # We can write the files using `cat`.
        workspace.execute_command(f"mkdir -p /workspace")

        # Copy expected.md
        workspace.execute_command(f"cat <<'EOF' > /workspace/expected.md\n{expected_table}\nEOF")

        # Copy paper.md (could be large, so checking size or using cat)
        # Assuming paper.md is text
        try:
            with open(Path(workspace_dir) / "paper.md", "r") as f:
                paper_content = f.read()
                # potential issue with escaping, but okay for markdown usually
                # Escape EOF if needed
                workspace.execute_command(f"cat <<'EOF' > /workspace/paper.md\n{paper_content}\nEOF")
        except Exception as e:
            logger.error(f"Failed to copy paper.md: {e}")

        agent = get_default_agent(llm=llm, cli_mode=True)

        # TODO: openhands current doesn't support cost_limit
        conversation = Conversation(
            agent=agent,
            workspace=workspace,
            max_iteration_per_run=step_limit,
        )

        logger.info(f"Sending prompt to agent...")
        conversation.send_message(prompt)

        # Enforce timeout using threading
        run_thread = threading.Thread(target=conversation.run, daemon=True)
        run_thread.start()
        run_thread.join(timeout=env_timeout)

        if run_thread.is_alive():
             logger.error(f"Agent timed out after {env_timeout} seconds.")
             # We can't easily kill the thread effectively in python without ctypes,
             # but we can stop the workspace which will fail the run.
             # The 'with' block exit will stop the container.
             pass

        logger.info("Agent finished execution.")

        # Check for submission artifacts
        # required: /workspace/repro_{artifact_name}_table_{table_index}.sh
        # Copy back result
        script_name = f"repro_{artifact_name}_table_{table_index}.sh"
        try:
             # Try to read the file content from container
             res = workspace.execute_command(f"cat /workspace/{script_name}")
             if res.exit_code == 0:
                 (Path(workspace_dir) / script_name).write_text(res.stdout, encoding="utf-8")
                 result = f"Recovered {script_name}"
             else:
                 logger.warning(f"Could not find submission script {script_name} in container output: {res.stdout} stderr: {res.stderr}")
                 result = "Submission script missing"
        except Exception as e:
             logger.error(f"Error recovering script: {e}")
             result = f"Error: {e}"

        # Artisan expects `traj_path` and `exit_status`.
        exit_status = "completed" # simplified

        if workspace_dir:
            traj_path = Path(workspace_dir) / "openhands.json"
            save_traj(conversation, traj_path, exit_status, result, llm=llm)

        return traj_path, exit_status
