# %%
import os
import subprocess
from datetime import datetime
from datetime import timezone

REPEAT_COUNT = 10

scripts_dir = '/home/doehyunbaek/artisan/evaluation/scripts'
[os.path.join(scripts_dir, f)
 for f in os.listdir(scripts_dir)
 if os.path.isfile(os.path.join(scripts_dir, f))]
# ['/home/doehyunbaek/artisan/evaluation/scripts/lasapp_table_2.sh',
# '/home/doehyunbaek/artisan/evaluation/scripts/urcrat_table_1.sh']
experiments = []
for fname in os.listdir(scripts_dir):
    fullpath = os.path.join(scripts_dir, fname)
    if os.path.isfile(fullpath):
        base, _ = os.path.splitext(fname)
        experiments.append(tuple(base.split('_')))
print(experiments)

# paper is id of paper
# kind is table
# index is table index
for paper, kind, index in experiments:
    for i in range(REPEAT_COUNT):
        cwd = os.path.expanduser("~/artisan/third_party/OpenHands")
        # create timestamp using UTC time for hour
        datestamp = datetime.now(timezone.utc).strftime("%y%m%d")
        timestamp = datetime.now(timezone.utc).strftime("%H%M")
        log_dir = os.path.join(cwd, "logs", f"{datestamp}/{paper}_{kind}_{index}")
        print(log_dir)
        os.makedirs(log_dir, exist_ok=True)
        log_file = os.path.join(log_dir, f"{timestamp}.log")

        # build command
        cmd = [
            "bash", "-c",
            f"LOG_ALL_EVENTS=true poetry run python -m openhands.core.main "
            f"-f /home/doehyunbaek/artisan/prompts/task_table.py &> {log_file}"
        ]
        subprocess.run(cmd, cwd=cwd, check=True)