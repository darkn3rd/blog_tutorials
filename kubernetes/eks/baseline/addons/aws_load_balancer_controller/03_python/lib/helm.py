"""lib/helm.py — Thin wrapper around the `helm` CLI.

The one deliberate exception to "boto3 and kubernetes instead of shelling
out": there is no official (or de facto standard) Python SDK for Helm, so
driving a chart install/uninstall from Python still means invoking the
`helm` binary. Everything else in this project (IAM, EKS, ELBv2,
CloudFormation, ServiceAccounts, CRDs, Ingress/Service/Gateway objects) goes
through boto3 or the kubernetes client directly with no subprocess calls at
all - this module is the single, intentional exception.
"""

from __future__ import annotations

import json
import subprocess

from lib.log import run_streamed


def add_repo(name: str, url: str) -> None:
    # `helm repo add` fails if the repo name is already registered, which
    # isn't an error worth surfacing here - the desired end state (repo
    # registered and up to date) is reached either way.
    subprocess.run(["helm", "repo", "add", name, url], capture_output=True, check=False)
    subprocess.run(["helm", "repo", "update", name], check=True, capture_output=True)


def upgrade_install(
    release_name: str,
    chart: str,
    namespace: str,
    version: str,
    values_yaml: str,
) -> int:
    """Runs `helm upgrade --install`, streaming output through
    lib.log.run_streamed. Returns the process exit code.
    """
    cmd = [
        "helm",
        "upgrade",
        "--install",
        "--version",
        version,
        "--namespace",
        namespace,
        release_name,
        chart,
        "--values",
        "-",
    ]
    proc = subprocess.Popen(
        cmd,
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1,
    )
    assert proc.stdin is not None
    proc.stdin.write(values_yaml)
    proc.stdin.close()

    assert proc.stdout is not None
    from lib.log import _timestamp  # local import to avoid a circular top-level import

    for line in proc.stdout:
        print(f"[{_timestamp()}]     | {line.rstrip()}")
    return proc.wait()


def release_exists(release_name: str, namespace: str) -> bool:
    result = subprocess.run(
        ["helm", "status", release_name, "--namespace", namespace],
        capture_output=True,
        check=False,
    )
    return result.returncode == 0


def uninstall(release_name: str, namespace: str) -> int:
    return run_streamed(["helm", "uninstall", release_name, "--namespace", namespace])


def get_release_info(release_name: str, namespace: str) -> dict | None:
    """Returns {"chart": ..., "app_version": ..., "status": ...} for the
    named release, or None if it isn't Helm-managed.
    """
    result = subprocess.run(
        ["helm", "list", "-n", namespace, "--filter", f"^{release_name}$", "-o", "json"],
        capture_output=True,
        text=True,
        check=False,
    )
    releases = json.loads(result.stdout or "[]")
    if not releases:
        return None
    return releases[0]
