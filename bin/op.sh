#!/usr/bin/env bash
set -eu

FILE="ops.json"

CMD="${1:-}"
NAME="${2:-}"

if [ -z "${CMD}" ]; then
  echo "使い方: $0 {add|rm|update|list} <プレイヤー名> [level] [bypassesPlayerLimit]"
  echo "  add:    OP 追加       (bypass 未指定なら false 固定)"
  echo "  rm:     OP 削除"
  echo "  update: 既存 OP 更新  (level / bypass 片方だけ更新も可)"
  echo "  list:   一覧表示"
  exit 1
fi

# ops.json が無ければ空配列で作る
if [ ! -f "$FILE" ]; then
  echo "[]" > "$FILE"
fi

case "$CMD" in
  add)
    LEVEL_RAW="${3:-4}"         # 未指定なら 4
    BYPASS_RAW="${4:-__DEFAULT__}"  # 未指定なら false にする

    if [ -z "${NAME}" ]; then
      echo "使い方: $0 add <プレイヤー名> [level] [bypass]"
      exit 1
    fi

    # LEVEL_RAW が数字かチェック
    if ! echo "$LEVEL_RAW" | grep -Eq '^[0-9]+$'; then
      echo "Error: level は数値で指定してください（1〜4 推奨）"
      exit 1
    fi
    LEVEL="$LEVEL_RAW"

    # bypass（第4引数）が無ければ false 固定
    if [ "$BYPASS_RAW" = "__DEFAULT__" ]; then
      BYPASS=false
    else
      case "$BYPASS_RAW" in
        1|true|TRUE|True|yes|YES|y|Y)
          BYPASS=true
          ;;
        0|false|FALSE|False|no|NO|n|N|"")
          BYPASS=false
          ;;
        *)
          BYPASS=false
          ;;
      esac
    fi

    echo "Mojang から UUID を取得中: $NAME ..."
    UUID_RAW=$(curl -s "https://api.mojang.com/users/profiles/minecraft/$NAME" | jq -r '.id')

    if [ "$UUID_RAW" = "null" ] || [ -z "$UUID_RAW" ]; then
      echo "Error: UUID が取得できませんでした（名前が間違っているかも？）"
      exit 1
    fi

    # UUID をハイフン付きへ変換
    UUID=$(echo "$UUID_RAW" | sed -E 's/(.{8})(.{4})(.{4})(.{4})(.{12})/\1-\2-\3-\4-\5/')

    # すでに登録済みか？
    if jq --arg uuid "$UUID" --arg name "$NAME" '
        map(select(.uuid == $uuid or .name == $name)) | length > 0
      ' "$FILE" | grep -q true; then
      echo "すでに OP に入っています：$NAME ($UUID)"
      exit 0
    fi

    TMP=$(mktemp)
    jq \
      --arg uuid "$UUID" \
      --arg name "$NAME" \
      --argjson level "$LEVEL" \
      --argjson bypass "$BYPASS" '
      . + [{
        "uuid": $uuid,
        "name": $name,
        "level": $level,
        "bypassesPlayerLimit": $bypass
      }]
    ' "$FILE" > "$TMP"

    mv "$TMP" "$FILE"
    echo "OP 追加しました：$NAME (level=$LEVEL, bypass=$BYPASS, uuid=$UUID)"
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
      echo "ops に見つかりませんでした：$NAME"
    else
      echo "OP から削除しました：$NAME"
    fi
    ;;

  update)
    LEVEL_RAW="${3:-__KEEP__}"      # "__KEEP__" の場合はレベル変更なし
    BYPASS_RAW="${4:-__KEEP__}"     # "__KEEP__" の場合は bypass 変更なし

    if [ -z "${NAME}" ]; then
      echo "使い方: $0 update <プレイヤー名> [level] [bypass]"
      echo "  level   を変えない場合は 省略 or \"\""
      echo "  bypass  を変えない場合は 省略"
      exit 1
    fi

    if [ "$LEVEL_RAW" = "__KEEP__" ] && [ "$BYPASS_RAW" = "__KEEP__" ]; then
      echo "Error: level か bypass のどちらかは指定してください"
      exit 1
    fi

    # 対象プレイヤーがいるか事前チェック
    if ! jq --arg name "$NAME" 'map(select(.name == $name)) | length > 0' "$FILE" | grep -q true; then
      echo "ops に見つかりませんでした：$NAME"
      exit 1
    fi

    # level の設定有無
    if [ "$LEVEL_RAW" = "__KEEP__" ] || [ -z "$LEVEL_RAW" ]; then
      LEVEL_SET=false
      LEVEL_VAL=0   # ダミー
    else
      if ! echo "$LEVEL_RAW" | grep -Eq '^[0-9]+$'; then
        echo "Error: level は数値で指定してください（1〜4 推奨）"
        exit 1
      fi
      LEVEL_SET=true
      LEVEL_VAL="$LEVEL_RAW"
    fi

    # bypass の設定有無
    if [ "$BYPASS_RAW" = "__KEEP__" ]; then
      BYPASS_SET=false
      BYPASS_VAL=false  # ダミー
    else
      case "$BYPASS_RAW" in
        1|true|TRUE|True|yes|YES|y|Y)
          BYPASS_SET=true
          BYPASS_VAL=true
          ;;
        0|false|FALSE|False|no|NO|n|N|"")
          BYPASS_SET=true
          BYPASS_VAL=false
          ;;
        *)
          echo "Error: bypass は true/false, 1/0, yes/no で指定してください"
          exit 1
          ;;
      esac
    fi

    TMP=$(mktemp)
    jq \
      --arg name "$NAME" \
      --argjson level_set "$LEVEL_SET" \
      --argjson new_level "$LEVEL_VAL" \
      --argjson bypass_set "$BYPASS_SET" \
      --argjson new_bypass "$BYPASS_VAL" '
      map(
        if .name == $name then
          (if $level_set  then .level = $new_level         else . end) |
          (if $bypass_set then .bypassesPlayerLimit = $new_bypass else . end)
        else
          .
        end
      )
    ' "$FILE" > "$TMP"

    mv "$TMP" "$FILE"
    echo -n "OP 更新しました：$NAME ("
    if [ "$LEVEL_SET" = true ]; then
      echo -n "level=$LEVEL_VAL "
    fi
    if [ "$BYPASS_SET" = true ]; then
      echo -n "bypass=$BYPASS_VAL "
    fi
    echo ")"
    ;;

  list)
    echo "=== ops.json ==="
    jq -r '.[] | "\(.name) (level=\(.level), bypass=\(.bypassesPlayerLimit), \(.uuid))"' "$FILE"
    ;;

  *)
    echo "不明なコマンドです: $CMD"
    echo "使い方: $0 {add|rm|update|list} <プレイヤー名> [level] [bypass]"
    exit 1
    ;;
esac
