#!/usr/bin/env bash
set -eu

LIST_FILE="${1:-list.txt}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
WHITELIST_SH="$SCRIPT_DIR/whitelist.sh"
MAX_RETRIES="${MAX_RETRIES:-3}"
RETRY_DELAY="${RETRY_DELAY:-2}"

if [ ! -f "$ROOT_DIR/$LIST_FILE" ] && [ ! -f "$LIST_FILE" ]; then
  echo "Error: list file が見つかりません: $LIST_FILE"
  echo "使い方: $0 [list.txt]"
  exit 1
fi

if [ -f "$ROOT_DIR/$LIST_FILE" ]; then
  LIST_PATH="$ROOT_DIR/$LIST_FILE"
else
  LIST_PATH="$LIST_FILE"
fi

if [ ! -x "$WHITELIST_SH" ]; then
  echo "Error: $WHITELIST_SH に実行権限がありません"
  echo "chmod +x $WHITELIST_SH を実行してください"
  exit 1
fi

FAILED_FILE=$(mktemp)
trap 'rm -f "$FAILED_FILE"' EXIT

COUNT=0
FAILED=0

add_with_retry() {
  NAME="$1"
  TRY=1

  while [ "$TRY" -le "$MAX_RETRIES" ]; do
    if "$WHITELIST_SH" add "$NAME"; then
      return 0
    fi

    if [ "$TRY" -lt "$MAX_RETRIES" ]; then
      echo "再試行します: $NAME ($TRY/$MAX_RETRIES)"
      sleep "$RETRY_DELAY"
    fi

    TRY=$((TRY + 1))
  done

  return 1
}

cd "$ROOT_DIR"

while IFS= read -r NAME || [ -n "$NAME" ]; do
  NAME=$(printf '%s' "$NAME" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g; s/^@//')

  if [ -z "$NAME" ]; then
    continue
  fi

  COUNT=$((COUNT + 1))

  if ! add_with_retry "$NAME"; then
    FAILED=$((FAILED + 1))
    echo "$NAME" >> "$FAILED_FILE"
  fi

  sleep 0.1
done < "$LIST_PATH"

echo
echo "=== whitelist 一括追加結果 ==="
echo "処理件数: $COUNT"
echo "失敗件数: $FAILED"

if [ "$FAILED" -gt 0 ]; then
  echo
  echo "UUID を取得できなかったプレイヤー:"
  cat "$FAILED_FILE"
  exit 1
fi
