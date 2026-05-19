#!/usr/bin/env bash
set -Eeuo pipefail

REMOTE="${REMOTE:-origin}"
TARGET_BRANCH="${TARGET_BRANCH:-gh-pages}"
SOURCE_DIR="${SOURCE_DIR:-books}"
DEST_DIR="${DEST_DIR:-books}"
COMMIT_MESSAGE="${COMMIT_MESSAGE:-Deploy books to GitHub Pages}"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

require_cmd git
require_cmd rsync

REPO_ROOT="$(git rev-parse --show-toplevel)"
SOURCE_PATH="$REPO_ROOT/$SOURCE_DIR"

if [[ ! -d "$SOURCE_PATH" ]]; then
  echo "Source directory does not exist: $SOURCE_PATH" >&2
  exit 1
fi

WORKTREE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/github-pages.XXXXXX")"

cleanup() {
  git -C "$REPO_ROOT" worktree remove --force "$WORKTREE_DIR" >/dev/null 2>&1 || rm -rf "$WORKTREE_DIR"
}
trap cleanup EXIT

if git -C "$REPO_ROOT" ls-remote --exit-code --heads "$REMOTE" "$TARGET_BRANCH" >/dev/null 2>&1; then
  git -C "$REPO_ROOT" fetch "$REMOTE" "$TARGET_BRANCH:refs/remotes/$REMOTE/$TARGET_BRANCH"
  git -C "$REPO_ROOT" worktree add -B "$TARGET_BRANCH" "$WORKTREE_DIR" "$REMOTE/$TARGET_BRANCH"
else
  git -C "$REPO_ROOT" worktree add --detach "$WORKTREE_DIR" HEAD
  git -C "$WORKTREE_DIR" switch --orphan "$TARGET_BRANCH"
fi

find "$WORKTREE_DIR" -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +

if [[ "$DEST_DIR" == "." || "$DEST_DIR" == "/" ]]; then
  rsync -a --delete "$SOURCE_PATH"/ "$WORKTREE_DIR"/
else
  mkdir -p "$WORKTREE_DIR/$DEST_DIR"
  rsync -a --delete "$SOURCE_PATH"/ "$WORKTREE_DIR/$DEST_DIR"/
fi

touch "$WORKTREE_DIR/.nojekyll"

git -C "$WORKTREE_DIR" add -A

if git -C "$WORKTREE_DIR" diff --cached --quiet; then
  echo "No changes to deploy."
  exit 0
fi

git -C "$WORKTREE_DIR" commit -m "$COMMIT_MESSAGE"
git -C "$WORKTREE_DIR" push "$REMOTE" "$TARGET_BRANCH"

echo "Published $SOURCE_DIR to $REMOTE/$TARGET_BRANCH."
echo "Configure GitHub Pages to deploy from branch '$TARGET_BRANCH' and folder '/'."
