import argparse
import logging
import os
import shutil
import subprocess
import sys
from pathlib import Path

# --- CRITICAL PATH FIX ---
# 1. Add Repo Root to sys.path so we can find the real 'artisan' and 'minisweagent' packages
_REPO_ROOT = Path(__file__).resolve().parents[2]
if str(_REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(_REPO_ROOT))

# 2. REMOVE the current directory (evaluation/agents) from sys.path.
#    This prevents 'import artisan' from accidentally loading 'evaluation/agents/artisan.py'
#    and 'import minisweagent' from loading 'evaluation/agents/minisweagent.py'.
_SCRIPT_DIR = str(Path(__file__).resolve().parent)
if _SCRIPT_DIR in sys.path:
    sys.path.remove(_SCRIPT_DIR)

# --- IMPORTS ---
# Now it is safe to import these without shadowing conflicts
import artisan
from artisan import util

logger = logging.getLogger("artisan.agents.sweagent")

_PROPAGATED_ENV_VARS: tuple[str, ...] = (
    "OPENAI_API_KEY",
    "AZURE_OPENAI_API_KEY",
    "ANTHROPIC_API_KEY",
)

def run_with_sweagent(
    workspace_dir: str,
    table_path: str,
    paper_path: str,
    artifact_url: str,
    interactive: bool,
    model_name: str | None = None,
    prompt_path: str | None = None,
) -> tuple[Path, str]:
    """
    Spawns a subprocess to run the heavy SWE-agent logic.
    """
    if interactive:
        logger.warning("Interactive mode is not supported for swe-agent.")

    workspace_path = Path(workspace_dir).expanduser().resolve()
    workspace_path.mkdir(parents=True, exist_ok=True)

    # Path to this very file to run it as a script
    script_path = Path(__file__).resolve()

    cmd = [
        sys.executable,
        str(script_path),
        "--workspace_dir", str(workspace_path),
        "--table_path", table_path,
        "--paper_path", str(paper_path),
        "--artifact_url", artifact_url,
    ]
    if model_name:
        cmd.extend(["--model_name", model_name])
    if prompt_path:
        cmd.extend(["--config_file", prompt_path])

    log_file = workspace_path / "sweagent_driver.log"

    # We must ensure the subprocess also prioritizes the repo root
    # and disables bytecode to prevent race conditions.
    env = {
        **os.environ,
        "PYTHONPATH": str(_REPO_ROOT),
        "PYTHONDONTWRITEBYTECODE": "1"
    }

    try:
        with open(log_file, "w") as f:
            # Run blocking subprocess
            subprocess.run(
                cmd,
                stdout=f,
                stderr=subprocess.STDOUT,
                check=True,
                env=env,
                cwd=str(_REPO_ROOT)
            )

        traj_path = workspace_path / f"{Path(table_path).stem}.traj"
        if traj_path.exists():
            return traj_path, "SUCCESS"
        return traj_path, "FAILED_NO_TRAJ"

    except subprocess.CalledProcessError:
        logger.error(f"swe-agent subprocess failed. See {log_file}")
        return workspace_path / "failure.traj", "SUBPROCESS_ERROR"
    except Exception as e:
        logger.error(f"Error invoking swe-agent subprocess: {e}")
        return workspace_path / "failure.traj", "INVOCATION_ERROR"


def _run_isolated_logic(
    workspace_dir: str,
    table_path: str,
    paper_path: str,
    artifact_url: str,
    model_name: str | None = None,
    config_file: str | None = None,
):
    """
    The actual agent logic.
    Imports are placed HERE to prevent the main process from freezing.
    """
    # --- LAZY IMPORTS START ---
    import litellm
    import yaml
    from swerex.deployment.config import DockerDeploymentConfig

    # Fix for models that don't support certain parameters (e.g. gpt-5-mini with top_p)
    litellm.drop_params = True

    from sweagent.agent.agents import DefaultAgent, DefaultAgentConfig, TemplateConfig
    from sweagent.agent.models import GenericAPIModelConfig
    from sweagent.agent.problem_statement import TextProblemStatement
    from sweagent.environment.swe_env import EnvironmentConfig, SWEEnv
    from sweagent.tools.tools import ToolConfig
    # --- LAZY IMPORTS END ---

    # Re-configure logging for this isolated process
    logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")

    def _load_prompt_config():
        if config_file:
            config_path = Path(config_file)
        else:
            repo_root = Path(util.find_repo_root())
            config_path = repo_root / "evaluation" / "prompts" / "sweagent.yaml"
        with config_path.open("r", encoding="utf-8") as fh:
            return yaml.safe_load(fh)

    config = _load_prompt_config()
    agent_section = config.get("agent", {}) or {}
    model_section = config.get("model", {}) or {}
    if model_name:
        model_section["model_name"] = model_name

    artifact_name = util.table_to_artifact(table_path)
    table_index = str(util.table_to_index(table_path))
    paper = util.table_to_paper(table_path)
    expected_table = util.get_original_table(paper, table_index)

    workspace_path = Path(workspace_dir)
    workspace_path.mkdir(parents=True, exist_ok=True)

    expected_md_path = workspace_path / "expected.md"
    expected_md_path.write_text(expected_table, encoding="utf-8")

    # Setup mounts
    docker_args = ["--privileged", "-v", f"{workspace_path}:/workspace:rw"]
    if os.getenv("ARTISAN_DOCKER_NETWORK") == "host":
        docker_args.extend(["--network", "host"])
    for env_var in _PROPAGATED_ENV_VARS:
        if env_var in os.environ:
            docker_args.extend(["-e", env_var])
    docker_args.extend(["-e", "MSWEA_SILENT_STARTUP=1"])

    host_cachedir = artisan.ARTISAN_CACHE_DIR
    container_cachedir = "/root/.cache/artisan"
    docker_args.extend(["-e", f"ARTISAN_CACHE_DIR={container_cachedir}"])
    docker_args.extend(["-e", f"ARTISAN_JUDGE_URL={artisan.ARTISAN_JUDGE_URL}"])
    if artisan.ARTISAN_MITM_URL:
        docker_args.extend(["-e", f"ARTISAN_MITM_URL={artisan.ARTISAN_MITM_URL}"])
    for env_var in ["REGISTRY_MIRROR", "INSECURE_REGISTRY"]:
        if os.getenv(env_var):
            docker_args.extend(["-e", env_var])
    docker_args.extend(["-v", f"{host_cachedir}:{container_cachedir}"])

    docker_socket = Path("/var/run/docker.sock")
    if docker_socket.exists():
        docker_args.extend(["--group-add", str(os.stat(docker_socket).st_gid)])

    container_paper_path = None
    if paper_path:
        src = Path(paper_path) 
        if src.exists():
            dest = workspace_path / "paper.md"
            shutil.copy2(src, dest)

    # Config
    template_config = TemplateConfig(**{k: agent_section[k] for k in ["system_template", "instance_template"] if k in agent_section})

    # Tool Config
    tools_section = agent_section.get("tools", {}) or {}
    env_vars = tools_section.get("env_variables", {}) or {}
    timeout = int(tools_section.get("execution_timeout", 28800))
    bundles = tools_section.get("bundles", [])

    tool_kwargs = {
        "env_variables": env_vars,
        "propagate_env_variables": [v for v in _PROPAGATED_ENV_VARS if v in os.environ],
        "execution_timeout": timeout,
        "install_timeout": timeout,
        "total_execution_timeout": timeout,
        "bundles": bundles,
    }
    if "format_error_template" in agent_section:
        tool_kwargs["format_error_template"] = agent_section["format_error_template"]

    tool_config = ToolConfig(**tool_kwargs)
    model_config = GenericAPIModelConfig(name=model_section.get("model_name"), **model_section.get("model_kwargs", {}))
    logger.info(tool_config)
    logger.info(model_config)

    agent_config = DefaultAgentConfig(templates=template_config, tools=tool_config, model=model_config)

    env_config = EnvironmentConfig(
        deployment=DockerDeploymentConfig(
            image=artisan.BASE_IMAGE,
            docker_args=docker_args,
            pull="missing",
        ),
    )

    instance_id = Path(table_path).stem
    extra_fields = {
        "artifact_name": artifact_name,
        "artifact_url": artifact_url,
        "table_index": table_index,
        "expected_table": expected_table,
        "paper_path": container_paper_path,
    }

    problem_statement = TextProblemStatement(
        text=f"Reproduce Table {table_index} for {paper}.",
        extra_fields={k: v for k, v in extra_fields.items() if v is not None},
        id=instance_id,
    )

    env = SWEEnv.from_config(env_config)
    agent = DefaultAgent.from_config(agent_config)
    result = None
    try:
        env.start()
        result = agent.run(env=env, problem_statement=problem_statement, output_dir=workspace_path)
    finally:
        try:
            env.close()
        except (TimeoutError, Exception) as e:
            logger.warning(f"Environment close operation failed: {e} - this is non-fatal, continuing anyway")

    if result is None:
        raise RuntimeError("swe-agent did not return a result")

    exit_status = str(result.info.get("exit_status", "UNKNOWN"))
    print(f"swe-agent finished with status {exit_status}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--workspace_dir", required=True)
    parser.add_argument("--table_path", required=True)
    parser.add_argument("--paper_path", required=True)
    parser.add_argument("--artifact_url", required=True)
    parser.add_argument("--model_name", default=None)
    parser.add_argument("--config_file", default=None)
    args = parser.parse_args()

    _run_isolated_logic(
        workspace_dir=args.workspace_dir,
        table_path=args.table_path,
        paper_path=args.paper_path,
        artifact_url=args.artifact_url,
        model_name=args.model_name,
        config_file=args.config_file,
    )