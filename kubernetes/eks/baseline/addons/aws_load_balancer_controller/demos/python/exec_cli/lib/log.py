"""lib/log.py — UTC-timestamped console output, one "[HH:MM:SS] message" per
line.
"""

import time


def timestamp() -> str:
    return time.strftime("%H:%M:%S", time.gmtime())


def info(message: str = "") -> None:
    print(f"[{timestamp()}] {message}")
