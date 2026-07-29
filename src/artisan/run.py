import argparse
import json
import logging
import os
import re
import shutil
import tempfile
import uuid
from pathlib import Path

import yaml

import artisan
from artisan import handle_paper, judge, speedometer, util
from artisan.tools import format
from minisweagent.agents.default import DefaultAgent, FormatError, Submitted
from minisweagent.environments.docker import DockerEnvironment
from minisweagent.models.litellm_model import LitellmModel
from minisweagent.run.utils.save import save_traj

logger = logging.getLogger(__name__)


def reason_to_feedback(result: judge.SubmissionResult, script_content: str | None = None) -> str:
    if result.status == judge.STATUS_STATIC_ERROR:
        if result.reason == judge.REASON_SCRIPT_MISSING:
            return "The submission script was not found. Please ensure you have created the script."
        if result.reason == judge.REASON_SYNTAX_FAIL:
            return f"The submission script has syntax errors:\n{result.stderr}"
        if result.reason == judge.REASON_READ_ERROR:
            return f"Could not read the submission script:\n{result.stderr}"

    elif result.status == judge.STATUS_RUNTIME_ERROR:
        if result.reason == judge.REASON_RUNTIME_FAIL:
            stderr = result.stderr
            if script_content:
                stderr = judge.format_runtime_error_context(script_content, stderr)
            return f"The submission script failed to execute:\n{stderr}"
        if result.reason == judge.REASON_JUDGE_INTERNAL_ERROR:
            return f"Internal judge error:\n{result.stderr}"

    elif result.status == judge.STATUS_MISMATCH_ERROR:
        if result.reason == judge.REASON_NO_BLOCK:
            return f"The submission script did not output a table within <artisan_submit> tags.\nError: {result.stderr}"
        if result.reason == judge.REASON_PARTIAL_MISMATCH:
            return (
                "The submitted table does not match the expected table.\n"
                "Here is the diff (mismatched digits are obfuscated with '?'):\n"
                f"{result.stdout}\n\n{result.stderr}"
            )
        if result.reason in [judge.REASON_DIFF_FULL, judge.REASON_DIFF_NONE]:
            return "The submitted table does not match the expected table."

    return f"Submission failed validation: {result.reason}\n{result.stderr}"


class DefaultAgentWithLogs(DefaultAgent):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.exit_validation_format_logs = []
        self.exit_validation_speedometer_logs = []
        self.last_judge_result = None

    def add_message(self, role, content, **kwargs):
        logger.debug("role: %s, content:\n%s", role, content)
        super().add_message(role, content, **kwargs)

    def parse_action(self, response: dict) -> dict:
        """Parse the action from the message. Returns the action."""
        actions = re.findall(r"<mini_swe_agent_bash>\n(.*?)\n</mini_swe_agent_bash>", response["content"], re.DOTALL)
        if len(actions) == 1:
            return {"action": actions[0].strip(), **response}
        raise FormatError(self.render_template(self.config.format_error_template, actions=actions))

    def validate_on_exit(self, output: dict[str, str]) -> bool:
        """
        Validates the submission script before finishing.
        Returns True if validation is skipped or successful, False if validation fails.
        """
        artifact_name = self.extra_template_vars.get("artifact_name")
        table_index = self.extra_template_vars.get("table_index")
        workspace_dir = self.extra_template_vars.get("workspace_dir")
        ablation = self.extra_template_vars.get("ablation")

        if not (artifact_name and table_index and workspace_dir):
            return True

        script_name = f"repro_{artifact_name}_table_{table_index}.sh"
        script_path = Path(workspace_dir) / script_name

        mode = "PART"
        if ablation == "without_output":
            mode = "WITHOUT_OUTPUT"
        elif ablation == "without_method":
            mode = "WITHOUT_METHOD"

        logger.info("Validating submission: %s (mode=%s)", script_path, mode)
        result = judge.check_submission_file(script_path, mode=mode)
        self.last_judge_result = result

        if result.format_logs:
            for log in result.format_logs:
                log["reason"] = format.REASON_EXIT_VALIDATION
            self.exit_validation_format_logs.extend(result.format_logs)

        if result.speedometer_logs:
            for log in result.speedometer_logs:
                log["reason"] = speedometer.REASON_EXIT_VALIDATION
            self.exit_validation_speedometer_logs.extend(result.speedometer_logs)

        if result.status not in [judge.STATUS_FULL_REPRO, judge.STATUS_LASTMILE_REPRO]:
            logger.info("Submission failed validation: %s", result.reason)
            script_content = None
            if script_path.exists():
                try:
                    script_content = script_path.read_text(encoding="utf-8")
                except Exception:
                    pass
            feedback = reason_to_feedback(result, script_content)
            output["output"] += f"\n\nSubmission failed validation:\n{feedback}\nPlease fix the script and try again."
            return False

        return True

    def has_finished(self, output: dict[str, str]):
        lines = output.get("output", "").lstrip().splitlines(keepends=True)
        if not lines or lines[0].strip() not in [
            "MINI_SWE_AGENT_FINAL_OUTPUT",
            "COMPLETE_TASK_AND_SUBMIT_FINAL_OUTPUT",
        ]:
            return

        if not self.validate_on_exit(output):
            return

        raise Submitted("".join(lines[1:]))


def run_with_artisan(
    workspace_dir: str,
    table_path: str,
    paper_path: str,
    artifact_url: str,
    interactive: bool,
    model_name: str | None = None,
    prompt_path: str | None = None,
    without_judge: bool = False,
    ablation: str | None = None,
):
    """Run the Artisan benchmark agent with yaml-configured mini-swe-agent settings."""
    del interactive

    artifact_name = util.table_to_artifact(table_path)
    table_index = util.table_to_index(table_path)
    paper = util.table_to_paper(table_path)
    expected_table = util.get_obfuscated_table(paper, table_index)

    with tempfile.NamedTemporaryFile(mode="w+", suffix=".md", delete=False) as tmpfile:
        tmpfile.write(expected_table)
        expected_table_path = tmpfile.name

    repo_root = Path(util.find_repo_root())
    config_path = Path(prompt_path) if prompt_path else repo_root / "artisanbench" / "prompts" / "artisan.yaml"
    with config_path.open("r", encoding="utf-8") as fh:
        config = yaml.safe_load(fh)

    model_kwargs = config.get("model", {}) or {}
    if model_name:
        model_kwargs["model_name"] = model_name
    model = LitellmModel(**model_kwargs)

    env_kwargs = config.get("environment", {}) or {}
    env_kwargs, container_paper_path = setup_workspace(
        paper,
        workspace_dir,
        paper_path,
        expected_table_path,
        env_kwargs,
    )
    env_kwargs["container_name"] = f"agent-{paper}-t{table_index}-{uuid.uuid4().hex[:4]}"
    env = DockerEnvironment(image=artisan.BASE_IMAGE, pull_timeout=3000, **env_kwargs)

    agent_config = config.get("agent", {}) or {}
    agent = DefaultAgentWithLogs(model, env, **agent_config)
    logger.info("Running DefaultAgent")

    exit_status, result = agent.run(
        "",
        artifact_name=artifact_name,
        table_index=table_index,
        expected_table=expected_table,
        paper_path=container_paper_path,
        artifact_url=artifact_url,
        workspace_dir=workspace_dir,
        without_judge=without_judge,
        ablation=ablation,
    )

    format_logs = []
    traj_path = Path(workspace_dir) / "mini.json"
    if workspace_dir:
        format_log_path = Path(workspace_dir) / "artisan-format.json"
        if format_log_path.exists():
            try:
                with format_log_path.open("r", encoding="utf-8") as f:
                    format_logs = json.load(f)
            except Exception as e:
                logger.warning("Failed to read format tool logs: %s", e)

        format_logs.extend(agent.exit_validation_format_logs)
        speedometer_logs = []

        speedometer_log_path = Path(workspace_dir) / "artisan-speedometer.json"
        if speedometer_log_path.exists():
            try:
                with speedometer_log_path.open("r", encoding="utf-8") as f:
                    speedometer_logs = json.load(f)
            except Exception as e:
                logger.warning("Failed to read speedometer tool logs: %s", e)

        speedometer_logs.extend(agent.exit_validation_speedometer_logs)

        if workspace_dir and agent.last_judge_result and not ablation:
            try:
                judge_result_path = Path(workspace_dir) / "judge_result.json"
                res = agent.last_judge_result
                data = {
                    "status": res.status,
                    "reason": res.reason,
                    "format_logs": res.format_logs,
                    "speedometer_logs": res.speedometer_logs,
                    "return_code": getattr(res, "return_code", None),
                    "stdout": getattr(res, "stdout", None),
                    "stderr": getattr(res, "stderr", None),
                }
                judge_result_path.write_text(json.dumps(data, indent=2), encoding="utf-8")
            except Exception as e:
                logger.warning("Failed to save judge result: %s", e)

        save_traj(
            agent,
            traj_path,
            exit_status=exit_status,
            result=result,
            extra_info={"format": format_logs, "speedometer": speedometer_logs},
        )  # type: ignore[arg-type]

    logger.info("Info status: %s", exit_status)
    logger.info("Result: %s", result)
    return traj_path, exit_status


def setup_workspace(
    paper: str,
    workspace_dir: str,
    paper_path: str,
    table_path: str,
    env_kwargs: dict,
) -> tuple[dict, str | None]:
    """Prepare a local workspace directory for mounting into the Docker environment."""
    ws_path = Path(workspace_dir).expanduser().resolve()
    ws_path.mkdir(parents=True, exist_ok=True)

    env_kwargs.setdefault("cwd", "/workspace")
    run_args = env_kwargs.setdefault("run_args", [])
    run_args.extend(["--rm"])
    run_args.extend(["--platform", "linux/amd64"])
    run_args.extend(["--privileged"])
    if os.getenv("ARTISAN_DOCKER_NETWORK") == "host":
        run_args.extend(["--network", "host"])
        logger.debug("Using host networking for Docker (--network host)")
    logger.debug("Added docker privileged mode")
    run_args.extend(["-e", "OPENAI_API_KEY"])
    logger.debug("Forwarded env var OPENAI_API_KEY")
    run_args.extend(["-e", "MSWEA_SILENT_STARTUP"])
    logger.debug("Forwarded env var MSWEA_SILENT_STARTUP")
    workspace_mount_spec = f"{ws_path}:/workspace:rw"
    run_args.extend(["-v", workspace_mount_spec])
    logger.debug("Added workspace volume mount: %s", workspace_mount_spec)
    run_args.extend(["-e", f"ARTISAN_JUDGE_URL={artisan.ARTISAN_JUDGE_URL}"])
    if artisan.ARTISAN_MITM_URL:
        run_args.extend(["-e", f"ARTISAN_MITM_URL={artisan.ARTISAN_MITM_URL}"])
    for env_var in ["REGISTRY_MIRROR", "INSECURE_REGISTRY"]:
        if os.getenv(env_var):
            run_args.extend(["-e", env_var])

    host_cachedir = artisan.ARTISAN_CACHE_DIR
    container_cachedir = "/root/.cache/artisan"
    run_args.extend(["-e", f"ARTISAN_CACHE_DIR={container_cachedir}"])
    run_args.extend(["-v", f"{host_cachedir}:{container_cachedir}"])
    logger.debug("Added artisan get cache mount")

    docker_socket = Path("/var/run/docker.sock")
    if docker_socket.exists():
        docker_gid = os.stat(docker_socket).st_gid
        run_args.extend(["--group-add", str(docker_gid)])
        logger.debug("Added docker socket volume mount: %s", docker_socket)

    def _copy_into_workspace(src_path_str: str, dest_name: str) -> str:
        src = Path(src_path_str).expanduser().resolve()
        dest = ws_path / dest_name
        shutil.copy2(src, dest)
        logger.info("Copied %s -> %s", src, dest)
        return f"/workspace/{dest.name}"

    del paper
    _copy_into_workspace(table_path, "expected.md")
    _copy_into_workspace(paper_path, "paper.md")
    return env_kwargs, None


def run(args, paper_data, workspace_dir):
    logger.debug(f"Paper data length: {len(paper_data)}")
    traj_path, exit_status = run_with_artisan(
        workspace_dir=workspace_dir,
        table_path=args.table,
        paper_path=paper_data["md_path"],
        artifact_url=args.artifact,
        interactive=args.interactive,
    )
    logger.info("Finished running")
    return traj_path, exit_status


def cmd_run(args):
    """
    Responsibilities:
    - Setup logging/workspace
    - Process paper into intermediate data
    - Dispatch to selected agent implementation
    """
    task = Path(args.table).stem if getattr(args, "table", None) else "run"
    logger, workspace_dir, _ = util.setup_logging(task)
    paper_data = handle_paper.process_paper(args.paper)
    return run(args, paper_data, workspace_dir)


def _run_from_cli(args: argparse.Namespace):
    """Adapter so argparse dispatch can call into cmd_run."""
    args.paper = args.paper if args.paper is not None else args.paper_pos
    args.artifact = args.artifact if args.artifact is not None else args.artifact_pos
    args.table = args.table if args.table is not None else args.table_pos

    missing = []
    if not args.paper:
        missing.append("paper")
    if not args.artifact:
        missing.append("artifact")
    if not args.table:
        missing.append("table")
    if missing:
        raise SystemExit(
            "Missing required argument(s): "
            + ", ".join(missing)
            + ". Provide `paper artifact table` or use --paper/--artifact/--table."
        )

    return cmd_run(args)


def register_subparser(subparsers: argparse._SubParsersAction) -> None:
    """Register the `artisan run` subparser with the shared CLI."""
    run_p = subparsers.add_parser("run", help="Run artifact reproduction workflow")
    run_p.add_argument("paper_pos", nargs="?", help="Paper path (positional order: paper artifact table)")
    run_p.add_argument("table_pos", nargs="?", help="Table path/index (positional order: paper artifact table)")
    run_p.add_argument("artifact_pos", nargs="?", help="Artifact URL (positional order: paper artifact table)")
    run_p.add_argument("--paper", dest="paper", default=None, help="Path to the paper file")
    run_p.add_argument("--artifact", dest="artifact", default=None, help="URL of the artifact to download")
    run_p.add_argument("--table", dest="table", default=None, help="Path/index of table to replicate")
    run_p.add_argument("--interactive", action="store_true", help="Enable interactive.")
    run_p.set_defaults(func=_run_from_cli)
