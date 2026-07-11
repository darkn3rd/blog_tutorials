"""lib/python_version.py — Checks the running Python meets this project's
minimum version. Fails fast with a clear message instead of a confusing
error deep in some module that happens to use newer syntax.
"""

import sys

MIN_PYTHON = (3, 9)


def verify_python() -> None:
    if sys.version_info < MIN_PYTHON:
        found = ".".join(str(part) for part in sys.version_info[:3])
        required = ".".join(str(part) for part in MIN_PYTHON)
        print(
            f"❌ This script requires Python >= {required}, found {found}.",
            file=sys.stderr,
        )
        sys.exit(1)
