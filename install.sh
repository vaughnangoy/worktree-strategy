#!/usr/bin/env bash
# install.sh — install prune-merged-worktrees into ~/.local/bin
# and register the global `git prune-worktrees` alias.
#
# Idempotent. Re-run to update.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="${SCRIPT_DIR}/bin/prune-merged-worktrees"
DEST_DIR="${HOME}/.local/bin"
DEST="${DEST_DIR}/prune-merged-worktrees"

if [ ! -f "${SRC}" ]; then
  echo "error: ${SRC} not found" >&2
  exit 1
fi

mkdir -p "${DEST_DIR}"
install -m 0755 "${SRC}" "${DEST}"
echo "✓ installed ${DEST}"

# PATH check.
if ! echo ":${PATH}:" | grep -q ":${DEST_DIR}:"; then
  echo
  echo "⚠ ${DEST_DIR} is not on your PATH."
  echo "  Add this to your ~/.zshrc (or ~/.bashrc):"
  echo
  echo "    export PATH=\"\$HOME/.local/bin:\$PATH\""
  echo
fi

# Git alias.
if command -v git >/dev/null 2>&1; then
  git config --global alias.prune-worktrees \
    '!f() { prune-merged-worktrees "$(git rev-parse --show-toplevel)"; }; f'
  echo "✓ registered git alias: git prune-worktrees"
else
  echo "⚠ git not found — skipping alias registration"
fi

# gh check (optional but recommended).
if ! command -v gh >/dev/null 2>&1; then
  echo
  echo "ℹ Recommended: install GitHub CLI for squash-merge detection:"
  echo "    brew install gh && gh auth login"
fi

echo
echo "Done. From inside any worktree of any repo, run:"
echo "    git prune-worktrees"
