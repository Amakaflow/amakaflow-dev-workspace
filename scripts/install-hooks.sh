#!/bin/sh
# Installs the pre-push git hook into every AmakaFlow repo.
# Run from anywhere — uses absolute paths.
#
# Usage:
#   ./scripts/install-hooks.sh              # install into all repos
#   ./scripts/install-hooks.sh /path/to/repo  # install into one repo

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK_SRC="$SCRIPT_DIR/pre-push"

AMAKAFLOW="$HOME/dev/AmakaFlow"

if [ -n "$1" ]; then
  REPOS="$1"
else
  REPOS="
    $AMAKAFLOW/amakaflow-dev-workspace
    $AMAKAFLOW/amakaflow-dev-workspace/amakaflow-db
    $AMAKAFLOW/chat-api
    $AMAKAFLOW/amakaflow-ios-app
    $AMAKAFLOW/amakaflow-android-app
    $AMAKAFLOW/amakaflow-automation
    $AMAKAFLOW/amakaflow-garmin-app
    $AMAKAFLOW/workoutkit-sync
  "
fi

# Also pick up any worktrees under ~/.config/superpowers/worktrees/
WORKTREE_BASE="$HOME/.config/superpowers/worktrees"
if [ -d "$WORKTREE_BASE" ]; then
  for wt in "$WORKTREE_BASE"/*/*; do
    [ -d "$wt" ] && REPOS="$REPOS $wt"
  done
fi

INSTALLED=0
SKIPPED=0

for REPO in $REPOS; do
  REPO="$(echo "$REPO" | tr -d ' ')"
  [ -z "$REPO" ] && continue

  # Check it's actually a git repo
  if [ ! -d "$REPO/.git" ] && [ ! -f "$REPO/.git" ]; then
    echo "  skip  $REPO (not a git repo)"
    SKIPPED=$((SKIPPED + 1))
    continue
  fi

  HOOKS_DIR="$REPO/.git/hooks"
  # For worktrees .git is a file — resolve the real hooks dir
  if [ -f "$REPO/.git" ]; then
    GIT_DIR="$(sed 's/gitdir: //' "$REPO/.git")"
    # GIT_DIR may be relative to the worktree root
    case "$GIT_DIR" in
      /*) ;;
      *) GIT_DIR="$REPO/$GIT_DIR" ;;
    esac
    HOOKS_DIR="$GIT_DIR/hooks"
  fi

  mkdir -p "$HOOKS_DIR"
  cp "$HOOK_SRC" "$HOOKS_DIR/pre-push"
  chmod +x "$HOOKS_DIR/pre-push"
  echo "  ✓     $REPO"
  INSTALLED=$((INSTALLED + 1))
done

echo ""
echo "Installed: $INSTALLED   Skipped: $SKIPPED"
