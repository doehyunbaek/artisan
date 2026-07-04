import json
import logging
import re
import shutil
import os
from pathlib import Path
import uuid
import yaml

from minisweagent.agents.default import DefaultAgent, FormatError
from minisweagent.agents.interactive import InteractiveAgent
from minisweagent.models.litellm_model import LitellmModel
from minisweagent.environments.docker import DockerEnvironment
from minisweagent.run.utils.save import save_traj

import artisan
from artisan import judge, util

logger = logging.getLogger("artisan.agents.artisan")

class DefaultAgentWithLogs(DefaultAgent):
    def add_message(self, role, content, **kwargs):
        logger.debug(f"role: {role}, content:\n{content}")
        super().add_message(role, content, **kwargs)

    def parse_action(self, response: dict) -> dict:
        """Parse the action from the message. Returns the action."""
        actions = re.findall(r"<mini_swe_agent_bash>\n(.*?)\n</mini_swe_agent_bash>", response["content"], re.DOTALL)
        if len(actions) == 1:
            return {"action": actions[0].strip(), **response}
        raise FormatError(self.render_template(self.config.format_error_template, actions=actions))


class InteractiveAgentWithLogs(InteractiveAgent):
    def add_message(self, role, content, **kwargs):
        logger.debug(f"role: {role}, content:\n{content}")
        super().add_message(role, content, **kwargs)

    def parse_action(self, response: dict) -> dict:
        """Parse the action from the message. Returns the action."""
        actions = re.findall(r"<mini_swe_agent_bash>\n(.*?)\n</mini_swe_agent_bash>", response["content"], re.DOTALL)
        if len(actions) == 1:
            return {"action": actions[0].strip(), **response}
        raise FormatError(self.render_template(self.config.format_error_template, actions=actions))


def get_except_glob(
    table_path: str,
    paper: str ,
    table_index: str
) -> str:
    if "restricted" not in table_path:
        return ""

    benchmark_path = Path(util.find_repo_root()) / "evaluation" / "benchmark.json"
    with benchmark_path.open("r", encoding="utf-8") as fh:
        benchmark = json.load(fh)

    table_key = str(table_index)
    for entry in benchmark:
        if entry.get("id") != paper:
            continue
        return f"--except {entry['tables'][f'{table_index}']['restricted']['except']}"
    return ""


def run_with_minisweagent(
    workspace_dir: str,
    table_path: str,
    paper_path: str,
    artifact_url: str,
    interactive: bool,
    model_name: str | None = None,
    prompt_path: str | None = None,
):
    """Run mini-swe-agent with the provided prompt using the inline YAML to configure the agent."""
    artifact_name = util.table_to_artifact(table_path)
    table_index = util.table_to_index(table_path)
    paper = util.table_to_paper(table_path)
    repo_root = Path(util.find_repo_root())

    # Always load the canonical (non-obfuscated) table, preferring
    # inconsistencies/ and partial/ when present.
    expected_table = util.get_original_table(paper, table_index)

    if prompt_path:
        config_path = Path(prompt_path)
    else:
        config_path = repo_root / "evaluation" / "prompts" / "minisweagent.yaml"
    with config_path.open("r", encoding="utf-8") as fh:
        config = yaml.safe_load(fh)
    model_kwargs = config.get("model", {}) or {}
    if model_name:
        model_kwargs["model_name"] = model_name
    model = LitellmModel(**model_kwargs)
    env_kwargs = config.get("environment", {}) or {}
    env_kwargs, container_paper_path = setup_workspace(
        paper, workspace_dir, paper_path, expected_table, env_kwargs
    )
    env_kwargs["container_name"] = f"agent-{paper}-t{table_index}-{uuid.uuid4().hex[:4]}"
    env = DockerEnvironment(image=artisan.BASE_IMAGE, pull_timeout=3000, **env_kwargs)

    agent_config = config.get("agent", {}) or {}
    if interactive:
        agent = InteractiveAgentWithLogs(model, env, **agent_config)
        logger.info("Running InteractiveAgent")
    else:
        agent = DefaultAgentWithLogs(model, env, **agent_config)
        logger.info("Running DefaultAgent")

    exit_status, result = agent.run(
        "",
        artifact_name=artifact_name,
        table_index=table_index,
        expected_table=expected_table,
        paper_path=container_paper_path,
        artifact_url=artifact_url,
        except_glob=get_except_glob(table_path, paper, table_index),
    )

    if workspace_dir:
        traj_path = Path(workspace_dir) / "mini.json"
        save_traj(agent, traj_path, exit_status=exit_status, result=result)  # type: ignore[arg-type]

    logger.info("Info status: %s", exit_status)
    logger.info("Result: %s", result)
    return traj_path, exit_status


def setup_workspace(
    paper: str,
    workspace_dir: str,
    paper_path: str,
    expected_table: str,
    env_kwargs: dict,
) -> tuple[str, str]:
    """Prepare a local workspace directory for mounting into the Docker environment."""
    ws_path = Path(workspace_dir).expanduser().resolve()
    ws_path.mkdir(parents=True, exist_ok=True)

    env_kwargs.setdefault("cwd", "/workspace")
    run_args = env_kwargs.setdefault("run_args", [])
    run_args.extend(["--rm"])
    run_args.extend(["--privileged"])
    if os.getenv("ARTISAN_DOCKER_NETWORK") == "host":
        run_args.extend(["--network", "host"])
        logger.debug("Using host networking for Docker (--network host)")
    logger.debug("Added docker privileged mode")
    run_args.extend(["-e", "OPENAI_API_KEY"])
    logger.debug(f"Forwarded env var OPENAI_API_KEY")
    run_args.extend(["-e", "MSWEA_SILENT_STARTUP"])
    logger.debug(f"Forwarded env var MSWEA_SILENT_STARTUP")
    workspace_mount_spec = f"{ws_path}:/workspace:rw"
    run_args.extend(["-v", workspace_mount_spec])
    logger.debug("Added workspace volume mount: %s", workspace_mount_spec)
    if artisan.ARTISAN_MITM_URL:
        run_args.extend(["-e", f"ARTISAN_MITM_URL={artisan.ARTISAN_MITM_URL}"])
    for env_var in ["REGISTRY_MIRROR", "INSECURE_REGISTRY"]:
        if os.getenv(env_var):
            run_args.extend(["-e", env_var])
    host_cachedir = artisan.ARTISAN_CACHE_DIR
    # container_cachedir = "/root/.cache/artisan"
    # run_args.extend(["-e", f"ARTISAN_CACHE_DIR={container_cachedir}"])
    # run_args.extend(["-e", f"ARTISAN_JUDGE_URL={artisan.ARTISAN_JUDGE_URL}"])
    # run_args.extend(["-v", f"{host_cachedir}:{container_cachedir}"])
    # logger.debug("Added artisan get cache mount")
    docker_socket = Path("/var/run/docker.sock")
    if docker_socket.exists():
        docker_gid = os.stat(docker_socket).st_gid
        run_args.extend(["--group-add", str(docker_gid)])
        logger.debug("Added docker socket volume mount: %s", docker_socket)

    def _copy_into_workspace(src_path_str: str, dest_name) -> str:
        src = Path(src_path_str).expanduser().resolve()
        dest = ws_path / dest_name
        shutil.copy2(src, dest)
        logger.info("Copied %s -> %s", src, dest)
        return f"/workspace/{dest.name}"

    (ws_path / "expected.md").write_text(expected_table, encoding="utf-8")
    _copy_into_workspace(paper_path, f"paper.md")
    return env_kwargs, None
