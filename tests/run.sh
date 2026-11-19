#!/usr/bin/env bash
# Run the model test suite.
#
# The virtualenv deliberately lives outside the plugin directory: Omarchy's
# plugin validator rejects symlinks anywhere inside a plugin folder, and a
# venv is full of them.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENV="${VEMBER_TEST_VENV:-$HOME/.cache/vember-server-hub/venv}"

if [ ! -x "$VENV/bin/python" ]; then
  echo "creating test venv at $VENV" >&2
  if command -v uv >/dev/null 2>&1; then
    uv venv "$VENV" >/dev/null
    uv pip install --python "$VENV/bin/python" pytest >/dev/null
  else
    python3 -m venv "$VENV"
    "$VENV/bin/pip" install --quiet pytest
  fi
fi

exec "$VENV/bin/python" -m pytest "$REPO/tests" "$@"
