#!/usr/bin/env python3
import os
import subprocess
import argparse
import tempfile
from datetime import datetime, timezone
from jinja2 import Environment, FileSystemLoader
import shutil

REPEAT_COUNT = int(os.getenv('REPEAT_COUNT', '1'))
MODEL_NAME = os.getenv('MODEL_NAME', 'openai/gpt-4o-mini')
API_KEY = os.environ.get('OPENAI_API_KEY', '')
# Print artisan git version
git_version = subprocess.check_output(["git", "describe", "--always", "--dirty"]).strip().decode()
print(f"Artisan Git Version: {git_version}")
# Print OpenHands git version
openhands_git_version = subprocess.check_output(
    ["git", "describe", "--always", "--dirty"],
    cwd=os.path.expanduser("~/artisan/third_party/OpenHands")
).strip().decode()
print(f"OpenHands Git Version: {openhands_git_version}")
print(f"Model name: {MODEL_NAME}")
print(f"Repeat count: {REPEAT_COUNT}")

TEMPLATE_DIR = os.path.expanduser('~/artisan/prompts')
TEMPLATE_NAME = 'task_table.j2'
env = Environment(loader=FileSystemLoader(TEMPLATE_DIR), trim_blocks=True, lstrip_blocks=True)
template = env.get_template(TEMPLATE_NAME)

evaluation_dir = os.path.expanduser("~/artisan/evaluation")
scripts_dir = os.path.join(evaluation_dir, "scripts")
tables_dir = os.path.join(evaluation_dir, "tables")

artisan_dir = os.path.expanduser("~/artisan")
openhands_dir = os.path.expanduser("~/artisan/third_party/OpenHands")

parser = argparse.ArgumentParser(description="Run a subset of experiments.")
parser.add_argument('paper', nargs='?', help='Paper name')
parser.add_argument('kind', nargs='?', help='Experiment kind')
parser.add_argument('index', nargs='?', help='Experiment index')
args = parser.parse_args()

def prepare_openhands_config(workspace_path):
    openhands_template_file = os.path.join(evaluation_dir, "openhands_config.j2")

    # 3. Set up the Jinja2 environment to find the template
    template_dir = os.path.dirname(openhands_template_file)
    template_filename = os.path.basename(openhands_template_file)
    env = Environment(loader=FileSystemLoader(template_dir), autoescape=False)
    template = env.get_template(template_filename)

    # 4. Render the template with your variables
    rendered_content = template.render(
        model_name=MODEL_NAME,
        openai_api_key=API_KEY,
        workspace_volume=workspace_path
    )

    # 5. Write the rendered content to a temporary TOML file
    with tempfile.NamedTemporaryFile(mode='w', delete=False, suffix=".toml") as temp_toml_file:
        temp_toml_file.write(rendered_content)
        # The final configuration file is now at this path
        openhands_toml = temp_toml_file.name 

    return openhands_toml    

experiments = []
for fname in os.listdir(scripts_dir):
    fullpath = os.path.join(scripts_dir, fname)
    if os.path.isfile(fullpath):
        base, _ = os.path.splitext(fname)
        experiments.append(tuple(base.split('_')))

# Filter experiments based on command-line arguments
filtered_experiments = []
if args.paper:
    filtered_experiments = [exp for exp in experiments if exp[0] == args.paper]
    if args.kind:
        filtered_experiments = [exp for exp in filtered_experiments if exp[1] == args.kind]
        if args.index:
            filtered_experiments = [exp for exp in filtered_experiments if exp[2] == args.index]
else:
    filtered_experiments = experiments

# Kill all docker openhands-related docker containers:
ids = subprocess.check_output(
    ["docker", "ps", "-q", "--filter", "ancestor=ghcr.io/all-hands-ai/runtime"],
    stderr=subprocess.DEVNULL
).split()
if ids:
    subprocess.run(["docker", "kill", *ids], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

for paper, kind, index in filtered_experiments:
    for run_idx in range(1, REPEAT_COUNT + 1):
        datestamp = datetime.now(timezone.utc).strftime("%y%m%d")
        timestamp = datetime.now(timezone.utc).strftime("%H%M")
        # path to your generated table
        table_path = f'{tables_dir}/{paper}_table_{index}.md'
        # read its contents
        with open(table_path, 'r') as tf:
            table_content = tf.read()
        # --- Render prompt template, inlining the table content ---
        rendered_prompt = template.render(
            docker_image=f"artisan25/{paper}",
            expected_table=table_content
        ).strip().replace('\n', '\\n').replace('"', '\\"')
        # rendered_prompt = "write a bash script that prints hi"
        # Prepare logging
        log_dir = os.path.join(artisan_dir, "logs", f"{datestamp}/{paper}_{kind}_{index}")
        os.makedirs(log_dir, exist_ok=True)
        workspace_dir = os.path.join(log_dir, f"{timestamp}_workspace")
        os.makedirs(workspace_dir, exist_ok=True)
        log_file = os.path.join(log_dir, f"{timestamp}.log")
        openhands_toml = prepare_openhands_config(workspace_dir)
        print(f"[Run {run_idx}] log → {log_file}")
        cmd = [
            "poetry", "run", "python", "-m", "openhands.core.main", "-b", "1", "-d", workspace_dir, "--config-file", openhands_toml,
            "-t", rendered_prompt
        ]
        env = os.environ.copy()
        env["LOG_ALL_EVENTS"] = "true"
        with open(log_file, "w") as lf:
            subprocess.run(
                cmd,
                cwd=openhands_dir,
                check=True,
                stdout=lf,
                stderr=subprocess.STDOUT,
                env=env
            )
        # Run docker container prune
        subprocess.run(["docker", "container", "prune", "-f"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        
