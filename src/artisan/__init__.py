import logging
import os
import pathlib
from pathlib import Path

OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
if not OPENAI_API_KEY:
    raise RuntimeError("OPENAI_API_KEY is not set; cannot call the OpenAI API for formatting.")

# agent

TIMEOUT = int(os.getenv("TIMEOUT", "1800"))
BUDGET = float(os.getenv("BUDGET", "1.0"))

# get
ARTISAN_JUDGE_TIMEOUT = os.getenv("ARTISAN_JUDGE_TIMEOUT") or 60 * 60 * 8  # 8 hours
ARTISAN_JUDGE_URL = os.getenv("ARTISAN_JUDGE_URL") or "http://localhost:8000/submit"
# Optional artifact-download proxy/cache. Disabled by default because pointing agent
# containers at localhost without running `artisan mitm` causes connection failures.
ARTISAN_MITM_URL = os.getenv("ARTISAN_MITM_URL", "")
ARTISAN_CACHE_DIR = Path(os.getenv("ARTISAN_CACHE_DIR") or os.getenv("XDG_CACHE_HOME") or Path.home() / ".cache")

# format
FORMAT_LOG_PATH = Path(os.environ.get("ARTISAN_FORMAT_LOG", "/workspace/artisan-format.json"))
FORMAT_MODEL = os.getenv("FORMAT_MODEL", "gpt-5-mini-2025-08-07")
SUCCESS_STRING = "Success: reproduce.sh output matches expected.md"

# speedometer
SPEEDOMETER_LOG_PATH = Path(os.environ.get("ARTISAN_SPEED_LOG", "/workspace/artisan-speedometer.json"))
SPEEDOMETER_MODEL = os.getenv("SPEEDOMETER_MODEL", "gpt-5-mini-2025-08-07")

## mini-swe-agent

## submit
BASE_IMAGE = os.getenv("ARTISAN_BASE_IMAGE", "doehyunbaek1/artisan:c268b22")
