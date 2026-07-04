import os
import argparse
import subprocess
import shlex
import time
from pathlib import Path

import artisan


def _preload_images(port: int, directory: Path) -> None:
    print(f"[artisan serve] _preload_images: port={port}, directory={directory}", flush=True)

    if not directory.exists():
        print("[artisan serve] cache dir does not exist, skipping preload", flush=True)
        return

    tars = sorted(directory.glob("*.tar"))
    if not tars:
        print("[artisan serve] no .tar files found, nothing to preload", flush=True)
        return

    print(f"[artisan serve] found {len(tars)} tar files to preload", flush=True)

    for tar in tars:
        print(f"[artisan serve] processing {tar}", flush=True)
        try:
            # load and capture output
            result = subprocess.run(
                ["docker", "load", "-i", str(tar)],
                text=True,
                capture_output=True,
                check=True,
            )
            print(result.stdout, end="", flush=True)
        except subprocess.CalledProcessError as e:
            print(f"[artisan serve] ERROR: docker load failed for {tar}: {e}", flush=True)
            print(e.stdout or "", end="", flush=True)
            print(e.stderr or "", end="", flush=True)
            continue

        loaded_images = []
        for line in result.stdout.splitlines():
            if "Loaded image:" in line:
                img = line.split("Loaded image:", 1)[1].strip()
                if img:
                    loaded_images.append(img)

        # [artisan serve] WARNING: no 'Loaded image:' lines for /home/doehyunbaek/.cache/artisan/docker/ppt4j.tar, skipping tag/push
        if not loaded_images:
            print(f"[artisan serve] WARNING: no 'Loaded image:' lines for {tar}, skipping tag/push", flush=True)
            continue

        for src in loaded_images:
            remote = f"localhost:{port}/{src}"
            print(f"[artisan serve] tagging {src} -> {remote}", flush=True)
            try:
                subprocess.run(["docker", "tag", src, remote], check=True)
                print(f"[artisan serve] pushing {remote}", flush=True)
                subprocess.run(["docker", "push", remote], check=True)
            except subprocess.CalledProcessError as e:
                print(f"[artisan serve] ERROR: tag/push failed for {src} -> {remote}: {e}", flush=True)
                print(e.stdout or "", end="", flush=True)
                print(e.stderr or "", end="", flush=True)

    print("[artisan serve] Preloading finished", flush=True)


def _serve_from_cli(args: argparse.Namespace) -> int:
    cmd = [
        "docker", "run", "--rm",
        "--name", args.name,
        "-p", f"{args.port}:5000",
    ]

    # MINIMAL CHANGE:
    # Only run as proxy cache if remoteurl is explicitly set.
    # Default: empty -> writable registry so pushes from _preload_images succeed.
    if args.remoteurl:
        cmd += [
            "-e", f"REGISTRY_PROXY_REMOTEURL={args.remoteurl}",
        ]

    cmd.append("registry:2")

    print("[artisan serve] Starting local Docker registry:", flush=True)
    print("  " + " ".join(shlex.quote(c) for c in cmd), flush=True)

    try:
        proc = subprocess.Popen(cmd)
    except Exception as e:
        print(f"[artisan serve] FAILED to start registry: {e}", flush=True)
        return 1

    print(f"[artisan serve] registry pid={proc.pid}", flush=True)

    try:
        time.sleep(2)

        if proc.poll() is not None:
            print(f"[artisan serve] registry exited early with code={proc.returncode}, skipping preload", flush=True)
            return proc.returncode

        if args.remoteurl:
            print("[artisan serve] proxy-cache mode enabled; skipping preload because registry proxies are read-through only", flush=True)
        else:
            print("[artisan serve] registry seems up, starting preload", flush=True)
            _preload_images(args.port, args.cachedir)
            print("[artisan serve] preload done, attaching to registry (Ctrl+C to stop)", flush=True)

        rc = proc.wait()
        print(f"[artisan serve] registry exited with code={rc}", flush=True)
        return rc

    except KeyboardInterrupt:
        print("\n[artisan serve] Stopping local Docker registry...", flush=True)
        proc.terminate()
        try:
            proc.wait(timeout=10)
        except subprocess.TimeoutExpired:
            print("[artisan serve] registry did not exit, killing...", flush=True)
            proc.kill()
        return 0


def register_subparser(subparsers: argparse._SubParsersAction) -> None:
    serve_p = subparsers.add_parser(
        "serve",
        help="Manually run a local Docker registry cache (pull-through or writable).",
    )
    serve_p.add_argument(
        "--port",
        type=int,
        default=int(os.environ.get("ARTISAN_REGISTRY_PORT", "5000")),
    )
    serve_p.add_argument(
        "--name",
        default=os.environ.get("ARTISAN_REGISTRY_NAME", "artisan-registry"),
    )
    serve_p.add_argument(
        "--remoteurl",
        # MINIMAL CHANGE: default empty -> writable registry by default
        default=os.environ.get("ARTISAN_REGISTRY_REMOTEURL", ""),
        help="If set, run as a proxy cache to this upstream (disables pushes).",
    )
    serve_p.add_argument(
        "--cachedir",
        default=Path(artisan.ARTISAN_CACHE_DIR) / "artisan" / "docker",
    )
    serve_p.set_defaults(func=_serve_from_cli)
