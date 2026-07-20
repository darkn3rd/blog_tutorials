"""lib/log.py — UTC-timestamped console output, one "[HH:MM:SS] message" per
line.
"""

import sys
import time


def timestamp() -> str:
    return time.strftime("%H:%M:%S", time.gmtime())


def info(message: str = "") -> None:
    print(f"[{timestamp()}] {message}")


def ok(message: str) -> None:
    print(f"[{timestamp()}] ✅ {message}")


def warn(message: str) -> None:
    print(f"[{timestamp()}] ⚠️  {message}", file=sys.stderr)


def error(message: str) -> None:
    print(f"[{timestamp()}] ❌ {message}", file=sys.stderr)


def section(title: str) -> None:
    print(f"[{timestamp()}] ==> {title}")
