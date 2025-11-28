# Minecraft Server OP & Whitelist Manager (CLI)

`ops.json` / `whitelist.json` を操作できる CLI ツールです。\
Minecraft サーバーを Docker や VPS で運用している人向けに最適化されています。

------------------------------------------------------------------------

## 📦 必要環境

-   bash
-   jq
-   curl
-   sed

Ubuntu / Debian 系では次で入ります：

``` bash
sudo apt install jq curl
```

------------------------------------------------------------------------

# 🚀 使用方法

## 🔧 実行権限の付与

``` bash
chmod +x ./bin/op.sh whitelist.sh
```

------------------------------------------------------------------------

# 🛠 OP 管理 (ops.json)

## 📥 追加（add）

### 標準（level=4, bypass=false）

``` bash
./bin/op.sh add nickname
```

### 権限レベルを指定して追加（bypass は false 固定）

``` bash
./bin/op.sh add nickname 2
```

### bypass を true にして追加

``` bash
./bin/op.sh add nickname 4 true
```

------------------------------------------------------------------------

## 🗑 削除（rm）

``` bash
./bin/op.sh rm nickname
```

------------------------------------------------------------------------

## 🔄 更新（update）

### レベルだけ更新

``` bash
./bin/op.sh update nickname 3
```

### bypass だけ更新

``` bash
./bin/op.sh update nickname "" true
```

### レベル + bypass 更新

``` bash
./bin/op.sh update nickname 4 true
```

------------------------------------------------------------------------

## 📃 一覧表示（list）

``` bash
./bin/op.sh list
```

------------------------------------------------------------------------

# 🧊 whitelist 管理 (whitelist.json)

## 📥 追加（add）

``` bash
./bin/whitelist.sh add nickname
```

## 🗑 削除（rm）

``` bash
./bin/whitelist.sh rm nickname
```

## 📃 一覧表示（list）

``` bash
./bin/whitelist.sh list
```
