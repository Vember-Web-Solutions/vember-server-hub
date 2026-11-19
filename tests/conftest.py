"""Shared fixtures for the Vember Server Hub model tests.

The model layer is pure JavaScript (ES modules). These tests drive it through
Node so the same code that QML loads is the code under test.
"""

import json
import shutil
import subprocess
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[1]
MODEL = REPO / "model"
NODE = shutil.which("node")

MODULES = [
    "Shell",
    "InstallLog",
    "Docker",
    "Systemd",
    "SystemInfo",
    "Tailscale",
    "Gaming",
    "DevTools",
    "Ssh",
    "Omarchy",
]

# Import every module once; tests then use `Shell.trim(...)` and friends.
PRELUDE = "\n".join(
    "import * as {0} from {1};".format(
        name, json.dumps((MODEL / (name + ".mjs")).as_uri())
    )
    for name in MODULES
)


@pytest.fixture(scope="session")
def js(tmp_path_factory):
    """Run a JS snippet that imports every model module; return its JSON output."""
    if NODE is None:
        pytest.skip("node is not installed")

    workdir = tmp_path_factory.mktemp("js")

    def run(body):
        script = PRELUDE + "\n" + body.strip() + "\n"
        path = workdir / "case.mjs"
        path.write_text(script)
        proc = subprocess.run(
            [NODE, str(path)], capture_output=True, text=True, timeout=60
        )
        assert proc.returncode == 0, proc.stderr
        lines = [line for line in proc.stdout.strip().splitlines() if line.strip()]
        assert lines, "JS produced no output"
        return json.loads(lines[-1])

    return run


@pytest.fixture
def stub_terminal(tmp_path):
    """A PATH entry whose xdg-terminal-exec runs the command directly."""
    bindir = tmp_path / "bin"
    bindir.mkdir()
    stub = bindir / "xdg-terminal-exec"
    stub.write_text(
        "#!/bin/sh\n"
        "# Ignore --flags, then exec the command the hub asked for.\n"
        'while [ $# -gt 0 ]; do case "$1" in --*) shift ;; *) break ;; esac; done\n'
        'exec "$@" </dev/null\n'
    )
    stub.chmod(0o755)
    return bindir
