"""lib/errors.py — Shared fatal-error helper.

Bash's die() is defined once per script and every sourced lib/*.sh file
assumes the sourcing script has already defined it. Python has no equivalent
"assumes the caller defines this" convention, so it lives here once and
every module imports it directly instead.
"""

import sys
from typing import NoReturn


def die(message: str) -> NoReturn:
    print(f"❌ {message}", file=sys.stderr)
    sys.exit(1)
