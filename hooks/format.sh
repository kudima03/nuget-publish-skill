#!/usr/bin/env bash
# Runs after Claude stops. Formats only if .cs files were touched in the working tree.
set -euo pipefail

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
SRC_DIR="${REPO_ROOT}/src"

[ -d "${SRC_DIR}" ] || exit 0

# Only run if there are modified/untracked .cs files
if git -C "${REPO_ROOT}" diff --name-only HEAD 2>/dev/null | grep -q '\.cs$' || \
   git -C "${REPO_ROOT}" ls-files --others --exclude-standard 2>/dev/null | grep -q '\.cs$'; then
  cd "${SRC_DIR}"
  csharpier format . 2>/dev/null && dotnet format 2>/dev/null || true
fi
