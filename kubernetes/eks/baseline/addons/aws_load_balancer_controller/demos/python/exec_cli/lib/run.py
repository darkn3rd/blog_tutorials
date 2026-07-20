"""lib/run.py — subprocess wrapper around kubectl.

Every kubectl call in this project goes through one of the two functions
below, so command construction and error surfacing are each handled in
exactly one place rather than repeated at every call site.
"""

from __future__ import annotations

import subprocess
from typing import Sequence

from lib.errors import die


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
    """Runs a command purely for its exit code - output is discarded
    either way.
    """
    result = subprocess.run(list(cmd), capture_output=True, text=True, check=False)
    return result.returncode == 0
