# Minecraft Server OP & Whitelist Manager (Windows)

Windows 環境で `ops.json` / `whitelist.json` を管理するための CLI ツールです。

## 動作環境

- PowerShell 5 以上（PowerShell 7 を推奨。`pwsh` があれば自動で優先利用します）
- インターネット接続（Mojang API から UUID を取得するため）

## 使い方

### 1. リポジトリ直下で実行

コマンドプロンプトまたは PowerShell を開き、リポジトリのルートに移動してから以下を実行します。`ops.json` / `whitelist.json` が無い場合は自動で作成されます。

### 2. OP 管理 (`ops.json`)

- 追加（デフォルト: level=4, bypass=false）  
  `.\bin\op.bat add <プレイヤー名>`
- 追加（レベル指定）  
  `.\bin\op.bat add <プレイヤー名> 2`
- 追加（レベル + bypass 指定）  
  `.\bin\op.bat add <プレイヤー名> 4 true`
- 削除  
  `.\bin\op.bat rm <プレイヤー名>`
- 更新（レベルや bypass を変更）  
  `.\bin\op.bat update <プレイヤー名> [level] [bypass]`
- 一覧表示  
  `.\bin\op.bat list`

### 3. Whitelist 管理 (`whitelist.json`)

- 追加  
  `.\bin\whitelist.bat add <プレイヤー名>`
- 削除  
  `.\bin\whitelist.bat rm <プレイヤー名>`
- 一覧表示  
  `.\bin\whitelist.bat list`

## 補足

- バッチ側で UTF-8 に切り替えてから PowerShell を呼び出すため、日本語メッセージの文字化けを避けられます。
- PowerShell 7+ (`pwsh`) がある場合はそちらを使い、無い場合は標準の Windows PowerShell を使います。
