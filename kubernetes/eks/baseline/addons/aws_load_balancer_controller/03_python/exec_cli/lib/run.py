"""lib/run.py — subprocess wrapper around the aws/kubectl/eksctl CLI tools.

Every external command in this project goes through one of the three
functions below, so command construction, error surfacing, and output
streaming are each handled in exactly one place rather than repeated at
every call site.
"""

from __future__ import annotations

import json
import subprocess
from typing import Any, Sequence

from lib.errors import die
from lib.log import timestamp


def run(cmd: Sequence[str], input_text: str | None = None, check: bool = True) -> str:
    """Runs a command, returns its stdout (stripped). Dies with the
    command's stderr on a non-zero exit if check=True.
    """
    result = subprocess.run(
        list(cmd), input=input_text, capture_output=True, text=True, check=False
    )
    if check and result.returncode != 0:
        die(f"Command failed ({result.returncode}): {' '.join(cmd)}\n{result.stderr.strip()}")
    return result.stdout.strip()


def run_ok(cmd: Sequence[str]) -> bool:
    """Runs a command purely for its exit code (existence checks etc.) -
    output is discarded either way.
    """
    result = subprocess.run(list(cmd), capture_output=True, text=True, check=False)
    return result.returncode == 0


def run_json(cmd: Sequence[str]) -> Any:
    """Runs a command and parses its stdout as JSON. Returns None if the
    command produced no output (e.g. an empty list result some CLIs print
    as nothing rather than "[]").
    """
    output = run(cmd)
    return json.loads(output) if output else None


def run_streamed(cmd: Sequence[str], input_text: str | None = None) -> int:
    """Runs a command, streaming its combined stdout/stderr through
    timestamped, indented lines as it runs rather than buffering until
    exit - for long-running calls (helm, eksctl, large kubectl applies)
    where silent output looks like a hang. Returns the exit code; unlike
    run(), does not die on failure, so the caller decides what a non-zero
    exit means for that particular call.
    """
    proc = subprocess.Popen(
        list(cmd),
        stdin=subprocess.PIPE if input_text is not None else None,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1,
    )
    if input_text is not None:
        assert proc.stdin is not None
        proc.stdin.write(input_text)
        proc.stdin.close()

    assert proc.stdout is not None
    for line in proc.stdout:
        print(f"[{timestamp()}]     | {line.rstrip()}")
    return proc.wait()
