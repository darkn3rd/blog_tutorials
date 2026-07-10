"""lib/policy_validation.py — IAM policy fingerprinting and statement
validation. Direct port of 01_cli/scripts/lib/policy_validation.sh.

A fingerprint is a normalised, order-independent representation of a
statement used for comparison:

  Effect    : kept as-is
  Action    : sorted list (strings coerced to a list first)
  Resource  : sorted list (strings coerced to a list first)
  Condition : keys sorted at every level; absent Condition -> explicit None

Two statements with the same actions in a different order are considered
equal. Two statements that differ only in Condition are always unequal.
"""

from __future__ import annotations

import difflib
import json
from typing import Any

from lib.aws import AwsClients, fetch_live_policy
from lib.log import info


def _as_list(value: Any) -> list[Any]:
    return [value] if isinstance(value, str) else list(value)


def _sort_condition(condition: dict[str, Any] | None) -> dict[str, Any] | None:
    if condition is None:
        return None

    def sort_level(value: Any) -> Any:
        if isinstance(value, dict):
            return {k: sort_level(value[k]) for k in sorted(value)}
        return value

    return sort_level(condition)


def fingerprint_statement(stmt: dict[str, Any]) -> str:
    normalized = {
        "Effect": stmt.get("Effect"),
        "Action": sorted(_as_list(stmt.get("Action", []))),
        "Resource": sorted(_as_list(stmt.get("Resource", []))),
        "Condition": _sort_condition(stmt.get("Condition")),
    }
    return json.dumps(normalized, sort_keys=True)


def build_fingerprint_map(policy: dict[str, Any]) -> dict[str, dict[str, Any]]:
    """Returns fingerprint -> original statement dict."""
    return {fingerprint_statement(stmt): stmt for stmt in policy["Statement"]}


def _first_action(stmt: dict[str, Any]) -> str:
    action = stmt["Action"]
    return action if isinstance(action, str) else action[0]


def _resource_label(stmt: dict[str, Any]) -> str:
    resource = stmt["Resource"]
    if isinstance(resource, str):
        label = resource
    elif len(resource) == 1:
        label = resource[0]
    else:
        label = f"[{len(resource)} resources]"
    # Strip "arn:aws:<service>:<region>:<account>:" the way the bash
    # version's sed does, for a shorter, more readable label.
    import re

    return re.sub(r"^arn:aws:[^:]*:[^:]*:[^:]*:", "", label)


def pretty_diff(expected: dict[str, Any], actual: dict[str, Any] | None) -> str:
    """Returns a unified diff between expected and actual. If actual is
    None (no match found), returns expected only with a note.
    """
    exp_pretty = json.dumps(expected, indent=2, sort_keys=True).splitlines(keepends=True)

    if actual is None:
        lines = ["    Expected statement (no match found in live policy):\n"]
        lines += [f"    {line}" for line in exp_pretty]
        return "".join(lines)

    act_pretty = json.dumps(actual, indent=2, sort_keys=True).splitlines(keepends=True)

    diff_lines = list(difflib.unified_diff(exp_pretty, act_pretty, n=3))[3:]  # drop the 3 header lines, mirroring `tail -n +4`
    formatted = []
    for line in diff_lines:
        if line.startswith("-"):
            formatted.append(f"    − {line[1:]}")
        elif line.startswith("+"):
            formatted.append(f"    + {line[1:]}")
        else:
            formatted.append(f"      {line}")
    return "".join(formatted)


def validate_policy(clients: AwsClients, policy_arn: str) -> bool:
    """Fetches the live policy and verifies every statement in
    EXPECTED_POLICY_JSON is present. Prints a grouped summary, then
    per-statement diffs on failure. Returns True if all statements match.
    """
    from lib.policy_definitions import EXPECTED_POLICY_JSON

    info("  Fetching live policy document...")
    live_policy = fetch_live_policy(clients, policy_arn)
    live_fingerprints = build_fingerprint_map(live_policy)

    expected_statements = EXPECTED_POLICY_JSON["Statement"]

    failed: list[tuple[int, dict[str, Any], dict[str, Any] | None]] = []

    print()
    print(f"  Required Statements  ({len(expected_statements)} total)")
    print("  " + "─" * 42)

    for i, exp_stmt in enumerate(expected_statements):
        exp_fp = fingerprint_statement(exp_stmt)
        first_action = _first_action(exp_stmt)
        action_count = 1 if isinstance(exp_stmt["Action"], str) else len(exp_stmt["Action"])
        resource_label = _resource_label(exp_stmt)

        if action_count > 1:
            label = f"{first_action}  (+{action_count - 1} more)  →  {resource_label}"
        else:
            label = f"{first_action}  →  {resource_label}"

        if exp_fp in live_fingerprints:
            print(f"  ✅  {label}")
        else:
            print(f"  ❌  {label}")
            # Closest-match heuristic: find a live statement sharing the first action.
            closest = None
            for live_stmt in live_fingerprints.values():
                if _first_action(live_stmt) == first_action:
                    closest = live_stmt
                    break
            failed.append((i, exp_stmt, closest))

    print()
    print("─" * 58)

    pass_count = len(expected_statements) - len(failed)

    if not failed:
        print(f"  ✅  All {len(expected_statements)} required statements are present.")
        print("─" * 58)
        return True

    print(f"  ❌  {pass_count} of {len(expected_statements)} statements matched  ({len(failed)} failed).")
    print("─" * 58)
    print()
    print("  Failed Statement Diffs")
    print("  " + "─" * 57)

    for i, exp_stmt, actual in failed:
        first_action = _first_action(exp_stmt)
        print()
        print(f"  Statement {i + 1}  ·  {first_action}  ...")
        print("  Legend:  − expected   + live policy")
        print()
        print(pretty_diff(exp_stmt, actual))
        print()
        print("  " + "·" * 53)

    return False
