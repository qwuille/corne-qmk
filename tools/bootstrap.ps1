# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Qwuille

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$vendorRoot = Join-Path $projectRoot '.build\vendor'
$lock = Get-Content -LiteralPath (Join-Path $projectRoot 'upstream.lock.json') -Raw | ConvertFrom-Json

New-Item -ItemType Directory -Force -Path $vendorRoot | Out-Null

function Install-PinnedRepository {
    param(
        [Parameter(Mandatory)] [string] $Name,
        [Parameter(Mandatory)] [string] $Url,
        [Parameter(Mandatory)] [string] $Commit,
        [switch] $Submodules
    )

    $destination = Join-Path $vendorRoot $Name
    if (-not (Test-Path -LiteralPath (Join-Path $destination '.git'))) {
        git clone --filter=blob:none $Url $destination
        if ($LASTEXITCODE -ne 0) { throw "Failed to clone $Url" }
    }

    git -c "safe.directory=$($destination -replace '\\','/')" -C $destination fetch --depth 1 origin $Commit
    if ($LASTEXITCODE -ne 0) { throw "Failed to fetch $Commit for $Name" }
    git -c "safe.directory=$($destination -replace '\\','/')" -C $destination checkout --detach $Commit
    if ($LASTEXITCODE -ne 0) { throw "Failed to check out $Commit for $Name" }

    if ($Submodules) {
        git -c "safe.directory=$($destination -replace '\\','/')" -C $destination submodule update --init --recursive --depth 1
        if ($LASTEXITCODE -ne 0) { throw "Failed to initialize submodules for $Name" }
    }
}

Install-PinnedRepository -Name 'vial-qmk' -Url $lock.vialQmk.url -Commit $lock.vialQmk.commit -Submodules
Install-PinnedRepository -Name 'xtips-qmk' -Url $lock.xtipsQmkKeyboard.url -Commit $lock.xtipsQmkKeyboard.commit
Install-PinnedRepository -Name 'foostan-kbd-firmware' -Url $lock.foostanKeyboardFirmware.url -Commit $lock.foostanKeyboardFirmware.commit -Submodules
Install-PinnedRepository -Name 'webdfu' -Url $lock.webDfu.url -Commit $lock.webDfu.commit

Write-Host 'Pinned firmware sources are ready under .build/vendor.'
