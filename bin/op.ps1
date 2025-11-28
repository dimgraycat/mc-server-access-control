#!/usr/bin/env pwsh
Param(
    [Parameter(Position = 0, Mandatory = $true)]
    [string]$Cmd,
    [Parameter(Position = 1, Mandatory = $false)]
    [string]$Name,
    [Parameter(Position = 2, Mandatory = $false)]
    [string]$LevelArg,
    [Parameter(Position = 3, Mandatory = $false)]
    [string]$BypassArg
)

$ErrorActionPreference = "Stop"

$File = "ops.json"

function Show-Usage {
    Write-Host "使い方:"
    Write-Host "  ops.ps1 add <プレイヤー名> [level] [bypass]"
    Write-Host "  ops.ps1 rm <プレイヤー名>"
    Write-Host "  ops.ps1 update <プレイヤー名> [level] [bypass]"
    Write-Host "  ops.ps1 list"
}

if (-not $Cmd) {
    Show-Usage
    exit 1
}

# ops.json が無ければ空配列で作成
if (-not (Test-Path $File)) {
    "[]" | Set-Content -Path $File -Encoding UTF8
}

# JSON 読み込み（空配列の場合のケア）
$raw = Get-Content -Path $File -Raw
if ([string]::IsNullOrWhiteSpace($raw)) {
    $ops = @()
} else {
    $ops = $raw | ConvertFrom-Json
    if ($ops -eq $null) { $ops = @() }
    if ($ops -isnot [System.Array]) { $ops = @($ops) }
}

function Save-Ops {
    param([array]$Data)
    ($Data | ConvertTo-Json -Depth 10) | Set-Content -Path $File -Encoding UTF8
}

function Get-UUID {
    param([string]$PlayerName)

    Write-Host "Mojang から UUID を取得中: $PlayerName ..."
    $url = "https://api.mojang.com/users/profiles/minecraft/$PlayerName"
    try {
        $resp = Invoke-RestMethod -Uri $url -Method Get -ErrorAction Stop
    } catch {
        Write-Host "Error: UUID が取得できませんでした（名前が間違っているか、API エラーかも？）"
        exit 1
    }

    if (-not $resp -or -not $resp.id) {
        Write-Host "Error: UUID が取得できませんでした（レスポンスが不正）"
        exit 1
    }

    $uuidRaw = $resp.id
    # ハイフン付きに変換
    $uuid = $uuidRaw -replace '(.{8})(.{4})(.{4})(.{4})(.{12})', '$1-$2-$3-$4-$5'
    return $uuid
}

function Parse-Bypass {
    param([string]$Value, [bool]$Default)

    if ($Value -eq $null -or $Value -eq "") {
        return $Default
    }

    switch -Regex ($Value.ToLower()) {
        "^(1|true|yes|y)$" { return $true }
        "^(0|false|no|n)$" { return $false }
        default            { return $Default }
    }
}

switch ($Cmd) {

    "add" {
        if (-not $Name) {
            Show-Usage
            exit 1
        }

        # level
        if (-not $LevelArg) {
            $level = 4
        } else {
            if (-not ($LevelArg -match '^\d+$')) {
                Write-Host "Error: level は数値で指定してください（1〜4 推奨）"
                exit 1
            }
            $level = [int]$LevelArg
        }

        # bypass: 第3引数(level) だけの場合は false 固定
        $bypass = Parse-Bypass -Value $BypassArg -Default:$false

        # すでに存在するかチェック
        $existing = $ops | Where-Object { $_.name -eq $Name }
        if ($existing) {
            Write-Host "すでに OP に入っています：$Name"
            exit 0
        }

        $uuid = Get-UUID -PlayerName $Name

        $new = [PSCustomObject]@{
            uuid                 = $uuid
            name                 = $Name
            level                = $level
            bypassesPlayerLimit  = $bypass
        }

        $ops += $new
        Save-Ops -Data $ops

        Write-Host "OP 追加しました：$Name (level=$level, bypass=$bypass, uuid=$uuid)"
    }

    { $_ -in @("rm", "del", "remove") } {
        if (-not $Name) {
            Show-Usage
            exit 1
        }

        $before = $ops.Count
        $ops = $ops | Where-Object { $_.name -ne $Name }
        $after = $ops.Count

        Save-Ops -Data $ops

        if ($before -eq $after) {
            Write-Host "ops に見つかりませんでした：$Name"
        } else {
            Write-Host "OP から削除しました：$Name"
        }
    }

    "update" {
        if (-not $Name) {
            Show-Usage
            exit 1
        }

        # level の更新有無
        $changeLevel = $false
        $newLevel = $null
        if ($PSBoundParameters.ContainsKey('LevelArg') -and $LevelArg -ne "" -and $LevelArg -ne $null) {
            if (-not ($LevelArg -match '^\d+$')) {
                Write-Host "Error: level は数値で指定してください（1〜4 推奨）"
                exit 1
            }
            $changeLevel = $true
            $newLevel = [int]$LevelArg
        }

        # bypass の更新有無
        $changeBypass = $false
        $newBypass = $null
        if ($PSBoundParameters.ContainsKey('BypassArg')) {
            $changeBypass = $true
            $newBypass = Parse-Bypass -Value $BypassArg -Default:$false
        }

        if (-not $changeLevel -and -not $changeBypass) {
            Write-Host "Error: level か bypass のどちらかは指定してください"
            exit 1
        }

        $target = $ops | Where-Object { $_.name -eq $Name }
        if (-not $target) {
            Write-Host "ops に見つかりませんでした：$Name"
            exit 1
        }

        foreach ($op in $ops) {
            if ($op.name -eq $Name) {
                if ($changeLevel)  { $op.level = $newLevel }
                if ($changeBypass) { $op.bypassesPlayerLimit = $newBypass }
            }
        }

        Save-Ops -Data $ops

        $msg = "OP 更新しました：$Name ("
        if ($changeLevel)  { $msg += "level=$newLevel " }
        if ($changeBypass) { $msg += "bypass=$newBypass " }
        $msg += ")"
        Write-Host $msg
    }

    "list" {
        Write-Host "=== ops.json ==="
        foreach ($op in $ops) {
            Write-Host ("{0} (level={1}, bypass={2}, {3})" -f $op.name, $op.level, $op.bypassesPlayerLimit, $op.uuid)
        }
    }

    default {
        Write-Host "不明なコマンドです: $Cmd"
        Show-Usage
        exit 1
    }
}
