#!/usr/bin/env python3
"""
start_weaviate.py — Download and start a local Weaviate binary.

No Docker needed. Data persists at ~/.weaviate-<project>/data/.

Usage:
  python start_weaviate.py
  python start_weaviate.py --project myapp
  python start_weaviate.py --port 8090 --project myapp
  python start_weaviate.py --background  # start and exit
"""

import argparse
import os
import platform
import stat
import subprocess
import sys
import tarfile
import time
import urllib.request
import zipfile
from pathlib import Path

WEAVIATE_VERSION = "1.36.9"

DOWNLOAD_URLS = {
    ("darwin", "arm64"): f"https://github.com/weaviate/weaviate/releases/download/v{WEAVIATE_VERSION}/weaviate-v{WEAVIATE_VERSION}-darwin-all.zip",
    ("darwin", "amd64"): f"https://github.com/weaviate/weaviate/releases/download/v{WEAVIATE_VERSION}/weaviate-v{WEAVIATE_VERSION}-darwin-all.zip",
    ("linux", "amd64"):  f"https://github.com/weaviate/weaviate/releases/download/v{WEAVIATE_VERSION}/weaviate-v{WEAVIATE_VERSION}-linux-amd64.tar.gz",
    ("linux", "arm64"):  f"https://github.com/weaviate/weaviate/releases/download/v{WEAVIATE_VERSION}/weaviate-v{WEAVIATE_VERSION}-linux-arm64.tar.gz",
}

BIN_DIR = Path.home() / ".weaviate-bin"


def get_platform_key() -> tuple[str, str]:
    system = platform.system().lower()
    machine = platform.machine().lower()
    arch = "arm64" if machine in ("arm64", "aarch64") else "amd64"
    return system, arch


def get_binary_path() -> Path:
    return BIN_DIR / f"weaviate-v{WEAVIATE_VERSION}"


def download_weaviate() -> Path:
    key = get_platform_key()
    url = DOWNLOAD_URLS.get(key)
    if not url:
        print(f"Unsupported platform: {key}. Download manually from https://github.com/weaviate/weaviate/releases")
        sys.exit(1)

    BIN_DIR.mkdir(parents=True, exist_ok=True)
    bin_path = get_binary_path()

    if bin_path.exists():
        print(f"Weaviate binary already at: {bin_path}")
        return bin_path

    is_targz = url.endswith(".tar.gz")
    archive_path = BIN_DIR / ("weaviate.tar.gz" if is_targz else "weaviate.zip")
    print(f"Downloading Weaviate v{WEAVIATE_VERSION} for {key[0]}/{key[1]}...")
    print(f"URL: {url}")

    def progress(block_num, block_size, total_size):
        downloaded = block_num * block_size
        if total_size > 0:
            pct = min(100, downloaded * 100 // total_size)
            print(f"\r  {pct}% ({downloaded // 1_000_000}MB / {total_size // 1_000_000}MB)", end="", flush=True)

    urllib.request.urlretrieve(url, archive_path, reporthook=progress)
    print()

    print("Extracting...")
    if is_targz:
        with tarfile.open(archive_path, "r:gz") as t:
            names = t.getnames()
            binary_name = next((n for n in names if "weaviate" in n.lower() and not n.endswith("/")), None)
            if not binary_name:
                print(f"Could not find weaviate binary in archive. Contents: {names}")
                sys.exit(1)
            member = t.getmember(binary_name)
            with t.extractfile(member) as src, open(bin_path, "wb") as dst:
                dst.write(src.read())
    else:
        with zipfile.ZipFile(archive_path, "r") as z:
            names = z.namelist()
            binary_name = next((n for n in names if "weaviate" in n.lower() and not n.endswith("/")), None)
            if not binary_name:
                print(f"Could not find weaviate binary in zip. Contents: {names}")
                sys.exit(1)
            with z.open(binary_name) as src, open(bin_path, "wb") as dst:
                dst.write(src.read())

    archive_path.unlink()
    bin_path.chmod(bin_path.stat().st_mode | stat.S_IEXEC | stat.S_IXGRP | stat.S_IXOTH)
    print(f"Weaviate binary ready at: {bin_path}")
    return bin_path


def _kill_existing(project: str, port: int) -> None:
    """Kill any previously running Weaviate instance for this project."""
    project_dir = Path.home() / f".weaviate-{project}"
    pid_file = project_dir / "weaviate.pid"

    # Kill by saved PID first
    if pid_file.exists():
        try:
            pid = int(pid_file.read_text().strip())
            os.kill(pid, 0)  # check if alive
            print(f"Stopping previous Weaviate process (PID {pid})...")
            os.kill(pid, 15)  # SIGTERM
            time.sleep(2)
            try:
                os.kill(pid, 9)  # SIGKILL if still alive
            except ProcessLookupError:
                pass
        except (ProcessLookupError, ValueError):
            pass
        pid_file.unlink(missing_ok=True)

    # Also kill anything holding the HTTP port
    try:
        result = subprocess.run(
            ["lsof", "-ti", f"tcp:{port}"],
            capture_output=True, text=True
        )
        for pid_str in result.stdout.strip().splitlines():
            try:
                os.kill(int(pid_str), 9)
            except (ProcessLookupError, ValueError):
                pass
    except FileNotFoundError:
        pass  # lsof not available


def start_weaviate(project: str, port: int, background: bool) -> None:
    bin_path = download_weaviate()

    _kill_existing(project, port)

    data_dir = Path.home() / f".weaviate-{project}" / "data"
    data_dir.mkdir(parents=True, exist_ok=True)

    grpc_port = port + 1

    env = os.environ.copy()
    env.update({
        "PERSISTENCE_DATA_PATH": str(data_dir),
        "QUERY_DEFAULTS_LIMIT": "25",
        "AUTHENTICATION_ANONYMOUS_ACCESS_ENABLED": "true",
        "DEFAULT_VECTORIZER_MODULE": "none",
        "ENABLE_MODULES": "",
        "CLUSTER_HOSTNAME": "node1",
        "GRPC_PORT": str(grpc_port),
        # Single-node bootstrap: tells Raft to elect itself immediately
        "RAFT_BOOTSTRAP_EXPECT": "1",
        # Raise the read-only disk threshold so local dev doesn't hit it
        "DISK_USE_READONLY_PERCENTAGE": "99",
        "DISK_USE_WARNING_PERCENTAGE": "95",
    })

    print(f"Starting Weaviate v{WEAVIATE_VERSION}")
    print(f"  Project:  {project}")
    print(f"  HTTP:     http://localhost:{port}")
    print(f"  gRPC:     localhost:{grpc_port}")
    print(f"  Data:     {data_dir}")
    print()

    cmd = [str(bin_path), "--scheme", "http", "--port", str(port)]

    if background:
        project_dir = Path.home() / f".weaviate-{project}"
        log_file = project_dir / "weaviate.log"
        pid_file = project_dir / "weaviate.pid"
        with open(log_file, "w") as log:
            proc = subprocess.Popen(cmd, env=env, stdout=log, stderr=log)
        pid_file.write_text(str(proc.pid))
        print(f"Weaviate started in background (PID {proc.pid})")
        print(f"Log: {log_file}")

        print("Waiting for Weaviate to be ready", end="", flush=True)
        import urllib.request as req
        deadline = time.time() + 60
        ready = False
        while time.time() < deadline:
            try:
                req.urlopen(f"http://localhost:{port}/v1/.well-known/ready", timeout=3)
                ready = True
                break
            except Exception:
                print(".", end="", flush=True)
                time.sleep(2)
        print()
        if ready:
            print(f"Health check: OK — http://localhost:{port}")
        else:
            print(f"ERROR: Weaviate did not become ready within 60s. Check log: {log_file}")
            sys.exit(1)
    else:
        print("Press Ctrl+C to stop Weaviate.")
        print()
        try:
            subprocess.run(cmd, env=env, check=True)
        except KeyboardInterrupt:
            print("\nWeaviate stopped.")


def main() -> None:
    parser = argparse.ArgumentParser(description="Start local Weaviate binary")
    parser.add_argument("--project", default=os.getenv("AGENTS_PROJECT", "default"),
                        help="Project name (used for data directory)")
    parser.add_argument("--port", type=int, default=int(os.getenv("WEAVIATE_PORT", "8090")),
                        help="HTTP port (default: 8090; gRPC = port+1)")
    parser.add_argument("--background", action="store_true",
                        help="Start Weaviate in background and exit")
    args = parser.parse_args()
    start_weaviate(args.project, args.port, args.background)


if __name__ == "__main__":
    main()
