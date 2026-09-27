# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Qwuille

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$distRoot = Join-Path $projectRoot 'dist'
$webRoot = Join-Path $projectRoot 'webhid'
$firmwareRoot = Join-Path $webRoot 'firmware'
$vendorRoot = Join-Path $webRoot 'vendor\webdfu'
$sourceRoot = Join-Path $projectRoot '.build\vendor\webdfu'
$lock = Get-Content -LiteralPath (Join-Path $projectRoot 'upstream.lock.json') -Raw | ConvertFrom-Json

$actualWebDfu = git -c "safe.directory=$($sourceRoot -replace '\\','/')" -C $sourceRoot rev-parse HEAD
if ($LASTEXITCODE -ne 0 -or $actualWebDfu.Trim() -ne $lock.webDfu.commit) {
    throw "WebDFU source is absent or not pinned to $($lock.webDfu.commit). Run tools/bootstrap.ps1."
}

$artifacts = @(
    [ordered]@{ id = 'xtips'; boardId = 1; name = 'XTIPS V4s / 103C'; transport = 'dfu'; file = 'xtips-v4s-103c-corne-control.bin' },
    [ordered]@{ id = 'szrkbd'; boardId = 2; name = 'SZRKBD Corne v4.1'; transport = 'uf2'; file = 'szrkbd-corne-v4.1-corne-control.uf2' },
    [ordered]@{ id = 'foostan'; boardId = 3; name = 'foostan Corne v4.1 standard'; transport = 'uf2'; file = 'foostan-corne-v4.1-corne-control.uf2' }
)

New-Item -ItemType Directory -Force -Path $firmwareRoot, $vendorRoot | Out-Null
foreach ($artifact in $artifacts) {
    $source = Join-Path $distRoot $artifact.file
    if (-not (Test-Path -LiteralPath $source)) {
        throw "Missing $source. Build all firmware targets first."
    }
    Copy-Item -LiteralPath $source -Destination (Join-Path $firmwareRoot $artifact.file) -Force
    $item = Get-Item -LiteralPath $source
    $artifact.size = $item.Length
    $artifact.sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $source).Hash.ToLowerInvariant()
}

Copy-Item -LiteralPath (Join-Path $sourceRoot 'dfu-util\dfu.js') -Destination (Join-Path $vendorRoot 'dfu.js') -Force
Copy-Item -LiteralPath (Join-Path $sourceRoot 'LICENSE') -Destination (Join-Path $vendorRoot 'LICENSE') -Force

$manifest = [ordered]@{
    format = 'corne-control-firmware'
    version = 1
    generatedUtc = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')
    artifacts = $artifacts
}
$json = $manifest | ConvertTo-Json -Depth 5
[IO.File]::WriteAllText((Join-Path $firmwareRoot 'manifest.json'), $json + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))

Write-Host "Web firmware package updated under $webRoot"
