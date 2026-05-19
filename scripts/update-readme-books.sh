#!/usr/bin/env bash
set -Eeuo pipefail

SOURCE_DIR="${SOURCE_DIR:-books}"
OUTPUT="${OUTPUT:-README.md}"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

require_cmd git

REPO_ROOT="$(git rev-parse --show-toplevel)"
SOURCE_PATH="$REPO_ROOT/$SOURCE_DIR"
OUTPUT_PATH="$REPO_ROOT/$OUTPUT"

if [[ ! -d "$SOURCE_PATH" ]]; then
  echo "Source directory does not exist: $SOURCE_PATH" >&2
  exit 1
fi

TMP_FILE="$(mktemp "${TMPDIR:-/tmp}/readme-books.XXXXXX")"

cleanup() {
  rm -f "$TMP_FILE"
}
trap cleanup EXIT

{
  echo "# books"
  echo
  echo "## 目录"

  current_category=""
  found=0

  while IFS= read -r file; do
    rel_path="${file#"$REPO_ROOT"/}"
    category_path="${rel_path#"$SOURCE_DIR"/}"
    category="${category_path%%/*}"
    title="$(basename "$file" .pdf)"

    if [[ "$category_path" == "$rel_path" || "$category" == "$category_path" ]]; then
      category="其他"
    fi

    if [[ "$category" != "$current_category" ]]; then
      echo
      echo "### $category"
      echo
      current_category="$category"
    fi

    echo "- [$title](<$rel_path>)"
    found=1
  done < <(find "$SOURCE_PATH" -type f -name '*.pdf' | sort)

  if [[ "$found" -eq 0 ]]; then
    echo
    echo "暂无书籍。"
  fi
} > "$TMP_FILE"

mv "$TMP_FILE" "$OUTPUT_PATH"
trap - EXIT

echo "Updated $OUTPUT from $SOURCE_DIR."
