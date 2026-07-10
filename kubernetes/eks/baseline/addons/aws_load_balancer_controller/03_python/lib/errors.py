"""lib/errors.py — Shared fatal-error helper."""

import sys
from typing import NoReturn


def die(message: str) -> NoReturn:
    print(f"❌ {message}", file=sys.stderr)
    sys.exit(1)
