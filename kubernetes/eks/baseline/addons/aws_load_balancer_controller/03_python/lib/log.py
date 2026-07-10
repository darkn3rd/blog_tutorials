"""lib/log.py — UTC-timestamped console output, matching the bash scripts'
per-line "[HH:MM:SS] message" convention (see 01_cli/install_aws_lbc.sh's
_tool_output_filter). Python calls boto3/kubernetes-client directly instead
of shelling out to CLI tools, so there's no equivalent repeated-heartbeat
noise (terraform's "Still creating...", eksctl's repeated "waiting for...")
to dedup here. The one remaining subprocess call is Helm (no Python SDK
exists for it - see lib/helm.py); its output is streamed and indented via
run_streamed() below to mark it as coming from an external tool, the same
visual convention the bash scripts use for terraform/eksctl output.
"""

import subprocess
import sys
import time
from typing import Sequence


def _timestamp() -> str:
    return time.strftime("%H:%M:%S", time.gmtime())


def info(message: str = "") -> None:
    print(f"[{_timestamp()}] {message}")


def ok(message: str) -> None:
    print(f"[{_timestamp()}] ✅ {message}")


def warn(message: str) -> None:
    print(f"[{_timestamp()}] ⚠️  {message}", file=sys.stderr)


def error(message: str) -> None:
    print(f"[{_timestamp()}] ❌ {message}", file=sys.stderr)


def section(title: str) -> None:
    print(f"[{_timestamp()}] ==> {title}")


def run_streamed(cmd: Sequence[str]) -> int:
    """Runs an external command (only ever helm - see module docstring),
    streaming its combined stdout/stderr through timestamped, indented
    lines as it runs rather than buffering until exit. Returns the
    command's exit code.
    """
    proc = subprocess.Popen(
        list(cmd),
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1,
    )
    assert proc.stdout is not None
    for line in proc.stdout:
        print(f"[{_timestamp()}]     | {line.rstrip()}")
    return proc.wait()
