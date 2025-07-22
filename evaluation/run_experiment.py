#!/usr/bin/env python3
import os
import subprocess
import argparse
from datetime import datetime, timezone
from jinja2 import Environment, FileSystemLoader
import shutil

REPEAT_COUNT = 1
TEMPLATE_DIR = '/home/doehyunbaek/artisan/prompts'
TEMPLATE_NAME = 'task_table.j2'
env = Environment(loader=FileSystemLoader(TEMPLATE_DIR), trim_blocks=True, lstrip_blocks=True)
template = env.get_template(TEMPLATE_NAME)

evaluation_dir = os.path.expanduser("~/artisan/evaluation")
scripts_dir = os.path.join(evaluation_dir, "scripts")
tables_dir = os.path.join(evaluation_dir, "tables")
openhands_toml = os.path.join(evaluation_dir, "openhands_config.toml")
openhands_dest = os.path.expanduser("~/artisan/third_party/OpenHands/config.toml")

shutil.copyfile(openhands_toml, openhands_dest)

parser = argparse.ArgumentParser(description="Run a subset of experiments.")
parser.add_argument('paper', nargs='?', help='Paper name')
parser.add_argument('kind', nargs='?', help='Experiment kind')
parser.add_argument('index', nargs='?', help='Experiment index')
args = parser.parse_args()

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
        cwd = os.path.expanduser("~/artisan/third_party/OpenHands")
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
        # Prepare logging
        log_dir = os.path.join(cwd, "logs", f"{datestamp}/{paper}_{kind}_{index}")
        os.makedirs(log_dir, exist_ok=True)
        log_file = os.path.join(log_dir, f"{timestamp}.log")
        print(f"[Run {run_idx}] log → {log_file}")
        cmd = [
            "poetry", "run", "python", "-m", "openhands.core.main", "-b", "0.5",
            "-t", rendered_prompt
        ]
        env = os.environ.copy()
        env["LOG_ALL_EVENTS"] = "true"
        with open(log_file, "w") as lf:
            subprocess.run(
                cmd,
                cwd=cwd,
                check=True,
                stdout=lf,
                stderr=subprocess.STDOUT,
                env=env
            )
