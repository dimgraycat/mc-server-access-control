#!/usr/bin/env bash
set -eu

FILE="whitelist.json"

CMD="${1:-}"
NAME="${2:-}"

if [ -z "${CMD}" ]; then
  echo "使い方: $0 {add|rm|list} <プレイヤー名>"
  exit 1
fi

# whitelist.json が無ければ空配列で作る
if [ ! -f "$FILE" ]; then
  echo "[]" > "$FILE"
fi

case "$CMD" in
  add)
    if [ -z "${NAME}" ]; then
      echo "使い方: $0 add <プレイヤー名>"
      exit 1
    fi

    echo "Mojang から UUID を取得中: $NAME ..."
    UUID_RAW=$(curl -s "https://api.mojang.com/users/profiles/minecraft/$NAME" | jq -r '.id')

    if [ "$UUID_RAW" = "null" ] || [ -z "$UUID_RAW" ]; then
      echo "Error: UUID が取得できませんでした（名前が間違っているかも？）"
      exit 1
    fi

    # ハイフン付き UUID に変換
    UUID=$(echo "$UUID_RAW" | sed -E 's/(.{8})(.{4})(.{4})(.{4})(.{12})/\1-\2-\3-\4-\5/')

    # すでに登録されているかチェック（name または uuid で）
    if jq --arg uuid "$UUID" --arg name "$NAME" '
        map(select(.uuid == $uuid or .name == $name)) | length > 0
      ' "$FILE" | grep -q true; then
      echo "すでに whitelist に入っています：$NAME ($UUID)"
      exit 0
    fi

    TMP=$(mktemp)
    jq --arg uuid "$UUID" --arg name "$NAME" '
      . + [{"uuid": $uuid, "name": $name}]
    ' "$FILE" > "$TMP"

    mv "$TMP" "$FILE"
    echo "追加しました：$NAME ($UUID)"
    ;;

  rm|del|remove)
    if [ -z "${NAME}" ]; then
      echo "使い方: $0 rm <プレイヤー名>"
      exit 1
    fi

    TMP=$(mktemp)
    BEFORE=$(jq 'length' "$FILE")
    jq --arg name "$NAME" '
      map(select(.name != $name))
    ' "$FILE" > "$TMP"
    mv "$TMP" "$FILE"
    AFTER=$(jq 'length' "$FILE")

    if [ "$BEFORE" = "$AFTER" ]; then
      echo "whitelist に見つかりませんでした：$NAME"
    else
      echo "削除しました：$NAME"
    fi
    ;;

  list)
    echo "=== whitelist.json ==="
    jq -r '.[] | "\(.name) (\(.uuid))"' "$FILE"
    ;;

  *)
    echo "不明なコマンドです: $CMD"
    echo "使い方: sh bin/$0 {add|rm|list} <プレイヤー名>"
    exit 1
    ;;
esac
