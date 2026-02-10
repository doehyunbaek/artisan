# %%
import json
import os
import sys
import asyncio, json, re, subprocess, nest_asyncio, shlex
from pathlib import Path
from urllib.parse import urljoin
from playwright.async_api import async_playwright, TimeoutError as PWTimeoutError


def run_async(coro):
    loop = asyncio.get_event_loop()
    if loop.is_running():
        nest_asyncio.apply()
        return loop.run_until_complete(coro)
    return asyncio.run(coro)


def find_repo_root(start: Path | None = None) -> Path:
    here = (start or Path(__file__)).resolve()
    for candidate in (here, *here.parents):
        if (candidate / ".git").exists():
            return candidate
    return None


ROOT = find_repo_root()
paper_sel_dir = ROOT / "artisanbench" / "select_papers_out"
paper_sel_dir.mkdir(parents=True, exist_ok=True)
artifacts_dir = Path("/var/artifacts")
artifacts_dir.mkdir(parents=True, exist_ok=True)

p1_1 = paper_sel_dir / "1_1-get-top-tier-se.json"
p1_2 = paper_sel_dir / "1_2-find-artifact-url.json"
p1_3 = paper_sel_dir / "1_3-download-artifacts.json"
p2 = paper_sel_dir / "2-exclude-non-docker.json"
p3 = paper_sel_dir / "3-exclude-external-api.json"
p4 = paper_sel_dir / "4-exclude-gpu.json"
p5 = paper_sel_dir / "5-exclude-long-time.json"
p6 = paper_sel_dir / "6-manual-reproduce.json"

# %%
# Step 1-1: 🤖 Get Top-tier SE conferences with Available & Reusable badges presented at 2024

BASE = "https://dl.acm.org"
CONF_NAME = ["ICSE", "FSE", "ASE", "ISSTA"]
NON_MAIN = ["SEIS", "NIER", "SEET", "Companion", "Vision", "Industry", "Journal First"]
YEAR = int(os.environ.get("SCRAPE_YEAR", "2024"))
BASE = "https://dl.acm.org"
START_ICSE = f"https://dl.acm.org/action/doSearch?fillQuickSearch=false&target=advanced&expand=dl&field1=ContentGroupTitle&text1=ICSE&ArtifactAnd=118213&startPage=0&pageSize=300&AfterYear={YEAR}&BeforeYear={YEAR}&ConceptID=118211"
START_ASE = f"https://dl.acm.org/action/doSearch?fillQuickSearch=false&target=advanced&expand=dl&field1=ContentGroupTitle&text1=ASE&ArtifactAnd=118213&startPage=0&pageSize=200&AfterYear={YEAR}&BeforeYear={YEAR}&ConceptID=118211"
START_ISSTA = f"https://dl.acm.org/action/doSearch?fillQuickSearch=false&target=advanced&expand=dl&field1=ContentGroupTitle&text1=ISSTA&ArtifactAnd=118213&startPage=0&pageSize=200&AfterYear={YEAR}&BeforeYear={YEAR}&ConceptID=118211"
# FSE is special because of PACMSE
START_FSE = f"https://dl.acm.org/action/doSearch?fillQuickSearch=false&target=advanced&expand=dl&ArtifactAnd=118213&AllField=ContentGroupTitle%3A%28FSE%29+OR+AllField%3A%28PACMSE%29&pageSize=200&AfterYear={YEAR}&BeforeYear={YEAR}&ConceptID=118211"
URLS = [START_ICSE, START_FSE, START_ASE, START_ISSTA]

# Behavior toggles via env (no parameters)
HEADFUL = os.environ.get("HEADFUL", "0").lower() in {"1", "true", "yes"}
DEVTOOLS = os.environ.get("DEVTOOLS", "0").lower() in {"1", "true", "yes"}


def _can_run_headful() -> bool:
    if sys.platform == "darwin":
        return True  # macOS: no DISPLAY needed
    if sys.platform.startswith("win"):
        return True  # Windows: no DISPLAY env
    return bool(os.environ.get("DISPLAY"))  # Linux/X11


async def scrape() -> list[dict]:
    """Return list of papers by crawling all pages from urls (no params)."""

    def _page_count_from_details(details: str) -> int | None:
        m = re.search(r"Pages?\s+(\d+)[–-](\d+)", details)
        if not m:
            return None
        a, b = map(int, m.groups())
        return b - a + 1 if b >= a else None

    def _should_skip(title: str, link: str | None, details: str) -> bool:
        pc = _page_count_from_details(details)
        if pc is not None and pc <= 4:
            return True
        return False

    TIMEOUT_MS = 60000
    results: list[dict] = []
    async with async_playwright() as pw:
        run_headful = _can_run_headful()
        browser = await pw.chromium.launch(
            headless=not run_headful,
            devtools=(DEVTOOLS and run_headful),
            args=[],
        )
        # Use this when blocked by bot detection
        # browser = await pw.chromium.connect_over_cdp("http://localhost:9222")
        try:
            context = await browser.new_context()
            page = await context.new_page()
            page.set_default_timeout(TIMEOUT_MS)

            for start_url in URLS:
                url = start_url
                while url:
                    await page.goto(url, timeout=TIMEOUT_MS)
                    # try to settle network a bit; be tolerant on slow pages
                    try:
                        await page.wait_for_load_state("domcontentloaded", timeout=TIMEOUT_MS)
                        await page.wait_for_load_state("networkidle", timeout=TIMEOUT_MS)
                    except PWTimeoutError:
                        pass

                    # wait until results or "no results" sentinel
                    await page.wait_for_selector(
                        "li.search__item.issue-item-container, .noResultsFoundWrapper",
                        timeout=TIMEOUT_MS,
                    )

                    containers = page.locator("li.search__item.issue-item-container")
                    count = await containers.count()
                    for i in range(count):
                        item = containers.nth(i)
                        # title + href
                        title_el = item.locator("h3.issue-item__title a").first
                        title = (await title_el.inner_text()).strip()
                        href = await title_el.get_attribute("href")
                        link = urljoin(BASE, href) if href else None
                        # authors
                        authors = await item.locator("ul.rlist--inline.loa li a").all_inner_texts()
                        # badges
                        badge_els = item.locator("div.badges a.simple-tooltip__block--b")
                        bcount = await badge_els.count()
                        badges = []
                        for j in range(bcount):
                            bt = await badge_els.nth(j).get_attribute("data-title")
                            if bt:
                                badges.append(bt)
                        # conf & details
                        details = (await item.locator("div.issue-item__detail").inner_text()).strip().replace("\n", " ")
                        if any(sub in details for sub in NON_MAIN):
                            continue
                        conf = next((c for c in CONF_NAME if c in details), None)

                        if _should_skip(title, link, details):
                            continue
                        results.append(
                            {
                                "title": title,
                                "conf": conf,
                                "year": YEAR,
                                "authors": authors,
                                "badges": badges,
                                "details": details,
                                "paper_url": link,
                            }
                        )

                    # pagination
                    next_links = page.locator('a[rel="next"]')
                    if await next_links.count() == 0 or (not await next_links.first.is_enabled()):
                        break
                    await next_links.first.click()
                    try:
                        await page.wait_for_load_state("domcontentloaded", timeout=TIMEOUT_MS)
                        await page.wait_for_load_state("networkidle", timeout=TIMEOUT_MS)
                    except PWTimeoutError:
                        pass

            # optional pause: only if headful+devtools
            if run_headful and DEVTOOLS:
                await page.pause()
        finally:
            await browser.close()
    return results


def run_step_1():
    data = run_async(scrape())
    print(f"Scraped total {len(data)} papers")
    with p1_1.open("w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)


# run_step_1()

# %%
# Step 1-2: ✍️ Find artifact url corresponding to the paper url
# NOTE: this part is done manually.
# NOTE: we manually exclude "VGX: Large-Scale Sample Generation for Boosting Learning-Based Software Vulnerability Analyses" (ICSE 2024) as it takes long to download but uses gpu anyway


# %%
# Step 1-3: 🤖 Download artifacts
def download_artifact(artifact_url: str, dest_dir: Path, max_artifact_bytes: int = 1_000_000_000) -> dict:
    dest_dir.mkdir(parents=True, exist_ok=True)

    # If directory already has content, we skip re-download to keep step idempotent.
    already_downloaded = any(dest_dir.iterdir())
    if not already_downloaded:
        print(f"Downloading: {artifact_url} -> {dest_dir}")
        proc = subprocess.run(["artisan", "get", artifact_url, "-o", str(dest_dir)], capture_output=True, text=True)
        if proc.returncode != 0:
            print(f"[WARN] artisan get failed (rc={proc.returncode}). stderr:\n{proc.stderr}")

    artifact_path = str(dest_dir)
    return artifact_path


def run_step_1_3(max_artifact_bytes: int = 1_000_000_000):
    with p1_2.open("r", encoding="utf-8") as f:
        input_rows: list[dict] = json.load(f)

    snap_p3: list[dict] = []
    total = len(input_rows)
    for idx, row in enumerate(input_rows, 1):
        title = row.get("title", "(untitled)")
        paper_id = title.replace(" ", "_").lower()
        dest_dir = artifacts_dir / paper_id

        print(f"[{idx}/{total}] Download: {title}")
        artifact_path = download_artifact(row["artifact_url"], dest_dir, max_artifact_bytes=max_artifact_bytes)
        row["artifact_path"] = artifact_path
        snap_p3.append(row)
        with p1_3.open("w", encoding="utf-8") as f:
            json.dump(snap_p3, f, indent=2)

    print(f"Step 1_3 done. p1_3={len(snap_p3)} rows.")


run_step_1_3()


# %%
# Step 2: 🤖 Exclude artifacts not using Docker
def uses_docker(root: Path) -> tuple[bool, bool]:
    rg_args = [
        "rg",
        "-i",
        "--glob",
        "**/*.md",
        "-g",
        "!**/data/**",
        "-g",
        "!**/dataset/**",
        "-g",
        "!**/datasets/**",
        "-e",
        "docker",
        "--",
        str(root),
    ]
    rg_cp = subprocess.run(rg_args, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    rg_hit = rg_cp.returncode == 0

    rga_args = [
        "rga",
        "-i",
        "--glob",
        "**/*.pdf",
        "-e",
        "docker",
        "--",
        str(root),
    ]
    rga_cp = subprocess.run(rga_args, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    rga_hit = rga_cp.returncode == 0

    if not (rg_hit or rga_hit):
        print("DOCKER RG CMD (bash-ready):\n", shlex.join(rg_args))
        print("DOCKER RGA CMD (bash-ready):\n", shlex.join(rga_args))
    return rg_hit, rga_hit


def run_step_2():
    with p1_3.open("r", encoding="utf-8") as f:
        rows: list[dict] = json.load(f)
    out_rows: list[dict] = []
    for row in rows:
        root = Path(row.get("artifact_path", ""))
        rg_hit, rga_hit = uses_docker(root)
        use = rg_hit or rga_hit
        row["uses_docker"] = use
        # NOTE: we manually exclude first paper as it is a false positive due to docker usage in one of its components.
        # NOTE: we manually exclude second paper as it is a false positive due to being a research about Dockerfiles but not packaged using Docker
        exclude_conditions = row.get(
            "title", ""
        ) == "A Transferability Study of Interpolation-Based Hardware Model Checking for Software Verification" or (
            row.get("title", "") == "Empirical Study of the Docker Smells Impact on the Image Size"
        )
        if use and (not exclude_conditions):
            out_rows.append(row)
    with p2.open("w", encoding="utf-8") as f:
        json.dump(out_rows, f, indent=2)
    print(f"Step 2 done. p2={len(out_rows)} rows.")


run_step_2()


# %%
# Step 3: 🤖 Exclude artifacts using external api
def uses_external_api(root: Path, should_print=False) -> tuple[bool, bool]:
    llm_args = [
        "rg",
        "-i",
        "--glob",
        "*.py",
        "--glob",
        "*.ipynb",
        "-e",
        r"\b(import|from)\s+(openai|anthropic)\b",
        str(root),
    ]
    toml_args = [
        "rg",
        "-i",
        "--glob",
        "*.toml",
        "-e",
        "etherscan",
        str(root),
    ]

    llm_cp = subprocess.run(llm_args, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    crypto_cp = subprocess.run(toml_args, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    rg_hit = llm_cp.returncode == 0
    toml_hit = crypto_cp.returncode == 0

    if rg_hit or should_print:
        print("Provider RG CMD (bash-ready):\n", shlex.join(llm_args))
    if toml_hit or should_print:
        print("Provider TOML RG CMD (bash-ready):\n", shlex.join(toml_args))

    return rg_hit or toml_hit


def run_step_3():
    with p2.open("r", encoding="utf-8") as f:
        rows: list[dict] = json.load(f)
    out_rows: list[dict] = []
    for row in rows:
        root = Path(row.get("artifact_path", ""))
        rg_hit = uses_external_api(root)
        use = rg_hit
        row["uses_api"] = use
        # NOTE: we manually include this paper as it is a optional import that is not used in the main artifact.
        include_conditions = row.get("title", "") == "Towards Finding Accounting Errors in Smart Contracts"
        if not use or include_conditions:
            out_rows.append(row)
    with p3.open("w", encoding="utf-8") as f:
        json.dump(out_rows, f, indent=2)
    print(f"Step 3 done. p3={len(out_rows)} rows.")


run_step_3()


# %%
# Step 4: 🤖 Exclude artifacts using gpu
def uses_gpu(root: Path, should_print: bool = False) -> tuple[bool, bool]:
    root = Path(root)

    rg_args = [
        "rg",
        "-i",
        # include only files with an extension
        "-g",
        "*.*",
        # excluded common non-code files
        "-g",
        "!**/*.txt",
        "-g",
        "!**/*.csv",
        "-g",
        "!**/*.json",
        "-g",
        "!**/*.jsonl",
        "-g",
        "!**/*.log",
        "-g",
        "!**/data/**",
        "-g",
        "!**/dataset/**",
        "-g",
        "!**/datasets/**",
        "-e",
        r"torch\.cuda|\bcuda\b|cudnn|tensorflow-gpu|nvidia-smi|device=cuda",
        "-e",
        r"FROM\s+nvidia/cuda|--gpus|NVIDIA_VISIBLE_DEVICES",
        str(root),
    ]
    try:
        rg_cp = subprocess.run(rg_args, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        # ripgrep exit codes: 0=match, 1=no match, 2=error
        rg_hit = rg_cp.returncode == 0
    except FileNotFoundError:
        rg_hit = False

    if rg_hit:
        print("GPU RG CMD (bash-ready):\n", shlex.join(rg_args))

    # Preserve original return shape (fd result unused). If you want both,
    # return (fd_hit, rg_hit) instead.
    return rg_hit


def run_step_4():
    with p3.open("r", encoding="utf-8") as f:
        rows: list[dict] = json.load(f)
    out_rows: list[dict] = []
    for row in rows:
        root = Path(row.get("artifact_path", ""))
        rg_hit = uses_gpu(root)
        use = rg_hit
        row["uses_gpu"] = use
        # NOTE: we manually include first paper as it is a false positive due to mentioning of "CUDA" in go-ethereum/README.md
        # NOTE: we manually include second paper as it is a false positive due to mentioning of "CUDA" in dependensies
        include_conditions = (
            row.get("title", "") == "Demystifying Invariant Effectiveness for Securing Smart Contracts"
            or row.get("title", "") == "ProveNFix: Temporal Property-Guided Program Repair"
        )
        # NOTE: we manually exclude this paper as it mentions "NVDIIA" in the paper.
        exclude_conditions = (
            row.get("title", "")
            == "SCTrans: Constructing a Large Public Scenario Dataset for Simulation Testing of Autonomous Driving Systems"
        )
        if not use and (not exclude_conditions) or include_conditions:
            out_rows.append(row)
    with p4.open("w", encoding="utf-8") as f:
        json.dump(out_rows, f, indent=2)
    print(f"Step 4 done. p4={len(out_rows)} rows.")


run_step_4()


# %%# Step 5: ✍️ Exclude artifacts taking long time (more than 8 hours)
def run_step_5():
    with p4.open("r", encoding="utf-8") as f:
        rows: list[dict] = json.load(f)
    out_rows: list[dict] = []
    for row in rows:
        # Excluded because "We set each baseline to run for 24 hours" in the paper
        s5_p1 = row.get("title", "") == "Finding XPath Bugs in XML Document Processors via Differential Testing"
        # Excluded because "The Docker was run on the same host machine as BVFINDER and each target cellular protocol task is fuzzed for 24 hours" in the paper
        s5_p2 = row.get("title", "") == "Semantic-Enhanced Static Vulnerability Detection in Baseband Firmware"
        # Excluded because "after a 12 hour runtime." in the paper
        s5_p3 = row.get("title", "") == "Fast Deterministic Black-box Context-free Grammar Inference"
        # Excluded because "greybox campaigns longer than 50 hours" in the paper
        s5_p4 = row.get("title", "") == "Extrapolating Coverage Rate in Greybox Fuzzing"
        # Excluded because "alone failed to reproduce the bugs within 24 hours" in the paper
        s5_p5 = row.get("title", "") == "Translation Validation for JIT Compiler in the V8 JavaScript Engine"
        # Excluded because "For our experiments, we set a maximum timeout of 12 hours for flakesync to run on each test" in the paper
        s5_p6 = row.get("title", "") == "FlakeSync: Automatically Repairing Async Flaky Tests"
        # Excluded because "We also conducted each experiment for 12 hours" in the paper
        s5_p7 = row.get("title", "") == "ECFuzz: Effective Configuration Fuzzing for Large-Scale Systems"
        # Excluded because "We repeated all the experiments 160 times, each with a timeout limit of 24 hours" in the paper
        s5_p8 = row.get("title", "") == "Evaluating Directed Fuzzers: Are We Heading in the Right Direction?"
        # Excluded because "In each experiment, we allocated a 24-hour testing period for each program" in the paper
        s5_p9 = (
            row.get("title", "") == "FeatMaker: Automated Feature Engineering for Search Strategy of Symbolic Execution"
        )
        # Excluded because "both cannot finish within 24 hours" in the paper
        s5_p10 = row.get("title", "") == "Scaler: Efficient and Effective Cross Flow Analysis"
        # Excluded because "within a 24-hour time budget using different tools and runtimes" in the paper
        s5_p11 = (
            row.get("title", "")
            == "WASMaker: Differential Testing of WebAssembly Runtimes via Semantic-Aware Binary Generation"
        )
        # Excluded because "Pyinder: about 12 hours" in the artifact: https://github.com/kupl/PyinderArtifact/blob/2f55b9b/EVALUATION.md?plain=1#L47
        s5_p12 = row.get("title", "") == "Towards Effective Static Type-Error Detection for Python"
        exclude_conditions = (
            s5_p1 or s5_p2 or s5_p3 or s5_p4 or s5_p5 or s5_p6 or s5_p7 or s5_p8 or s5_p9 or s5_p10 or s5_p11 or s5_p12
        )
        if not exclude_conditions:
            out_rows.append(row)
    with p5.open("w", encoding="utf-8") as f:
        json.dump(out_rows, f, indent=2)
    print(f"Step 5 done. p5={len(out_rows)} rows.")


run_step_5()


# %%
# Step 6: ✍️ Manually try to reproduce artifacts for maximum eight hours.
def run_step_6():
    with p5.open("r", encoding="utf-8") as f:
        rows: list[dict] = json.load(f)
    out_rows: list[dict] = []
    for row in rows:
        # Excluded because a script to generate paper results from raw data is missing
        s6_p1 = (
            row.get("title", "")
            == "CoderEval: A Benchmark of Pragmatic Code Generation with Generative Pre-trained Models"
        )
        # Excluded because data for the result of user study is missing
        s6_p2 = row.get("title", "") == "Scaling Code Pattern Inference with Interactive What-If Analysis"
        # Excluded because docker image in the artifact is missing: `docker pull icseartifact/sae`
        s6_p3 = row.get("title", "") == "Precise Sparse Abstract Execution via Cross-Domain Interaction"
        # Excluded because full benchmark is missing. Only MongoDB is included
        s6_p4 = (
            row.get("title", "")
            == "CNEPS: A Precise Approach for Examining Dependencies among Third-Party C/C++ Open-Source Components"
        )
        # Excluded because full benchmark is missing. Only a small sample inputs are included
        s6_p5 = (
            row.get("title", "")
            == "MotorEase: Automated Detection of Motor Impairment Accessibility Issues in Mobile App UIs"
        )
        # Excluded because data for "Table 2. Taxonomy description including # of positive and negative comments on the perception of realism" is missing
        s6_p6 = (
            row.get("title", "") == "How Does Simulation-Based Testing for Self-Driving Cars Match Human Perception?"
        )
        # Excluded because a script to generate paper results from results.csv is missing
        s6_p7 = row.get("title", "") == "Semistructured Merge with Language-Specific Syntactic Separators"
        # Excluded because output is nondeterministic
        s6_p8 = row.get("title", "") == "Define-Use Guided Path Exploration for Better Forced Execution"
        # Excluded because output is nondeterministic
        s6_p9 = (
            row.get("title", "")
            == "FuzzSlice: Pruning False Positives in Static Analysis Warnings through Function-Level Fuzzing"
        )
        exclude_conditions = s6_p1 or s6_p2 or s6_p3 or s6_p4 or s6_p5 or s6_p6 or s6_p7 or s6_p8 or s6_p9
        if not exclude_conditions:
            out_rows.append(row)
    print(f"Step 6 done. p6={len(out_rows)} rows.")
    with p6.open("w", encoding="utf-8") as f:
        json.dump(out_rows, f, indent=2)


run_step_6()
# %%
