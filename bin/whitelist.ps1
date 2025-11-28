#!/usr/bin/env pwsh
Param(
    [Parameter(Position = 0, Mandatory = $true)]
    [string]$Cmd,
    [Parameter(Position = 1, Mandatory = $false)]
    [string]$Name
)

$ErrorActionPreference = "Stop"

$File = "whitelist.json"

function Show-Usage {
    Write-Host "使い方:"
    Write-Host "  whitelist.ps1 add <プレイヤー名>"
    Write-Host "  whitelist.ps1 rm <プレイヤー名>"
    Write-Host "  whitelist.ps1 list"
}

if (-not $Cmd) {
    Show-Usage
    exit 1
}

# whitelist.json が無ければ空配列で作成
if (-not (Test-Path $File)) {
    "[]" | Set-Content -Path $File -Encoding UTF8
}

$raw = Get-Content -Path $File -Raw
if ([string]::IsNullOrWhiteSpace($raw)) {
    $list = @()
} else {
    $list = $raw | ConvertFrom-Json
    if ($list -eq $null) { $list = @() }
    if ($list -isnot [System.Array]) { $list = @($list) }
}

function Save-Whitelist {
    param([array]$Data)

    $arr = @(@($Data) | Where-Object { $_ -ne $null })  # ensure array and drop nulls
    if ($arr.Count -eq 0) {
        "[]" | Set-Content -Path $File -Encoding UTF8
    } else {
        (ConvertTo-Json -InputObject $arr -Depth 10) | Set-Content -Path $File -Encoding UTF8
    }
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
    $uuid = $uuidRaw -replace '(.{8})(.{4})(.{4})(.{4})(.{12})', '$1-$2-$3-$4-$5'
    return $uuid
}

switch ($Cmd) {

    "add" {
        if (-not $Name) {
            Show-Usage
            exit 1
        }

        $exists = $list | Where-Object { $_.name -eq $Name }
        if ($exists) {
            Write-Host "すでに whitelist に入っています：$Name"
            exit 0
        }

        $uuid = Get-UUID -PlayerName $Name

        $new = [PSCustomObject]@{
            uuid = $uuid
            name = $Name
        }

        $list += $new
        Save-Whitelist -Data $list

        Write-Host "whitelist に追加しました：$Name ($uuid)"
    }

    { $_ -in @("rm", "del", "remove") } {
        if (-not $Name) {
            Show-Usage
            exit 1
        }

        $before = $list.Count
        $list = $list | Where-Object { $_.name -ne $Name }
        $after = $list.Count

        Save-Whitelist -Data $list

        if ($before -eq $after) {
            Write-Host "whitelist に見つかりませんでした：$Name"
        } else
            { Write-Host "whitelist から削除しました：$Name" }
    }

    "list" {
        Write-Host "=== whitelist.json ==="
        foreach ($w in $list) {
            Write-Host ("{0} ({1})" -f $w.name, $w.uuid)
        }
    }

    default {
        Write-Host "不明なコマンドです: $Cmd"
        Show-Usage
        exit 1
    }
}
