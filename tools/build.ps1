# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Qwuille

[CmdletBinding()]
param(
    [ValidateSet('all', 'xtips', 'szrkbd', 'foostan')]
    [string] $Target = 'all'
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$vendorRoot = Join-Path $projectRoot '.build\vendor'
$distRoot = Join-Path $projectRoot 'dist'
$lock = Get-Content -LiteralPath (Join-Path $projectRoot 'upstream.lock.json') -Raw | ConvertFrom-Json
$vialPatch = Join-Path $projectRoot 'patches\vialrgb-policy-and-split-sync.patch'
$tapDancePatch = Join-Path $projectRoot 'patches\vial-tap-dance-reliable-interrupt.patch'
$tapDanceDelayPatch = Join-Path $projectRoot 'patches\vial-tap-dance-minimum-delay.patch'
$stableBuildIdPatch = Join-Path $projectRoot 'patches\vial-stable-build-id.patch'
$commonRoot = Join-Path $projectRoot 'firmware\common'
. (Join-Path $PSScriptRoot 'firmware-storage.ps1')

# Vial stores the low 24 bits of BUILD_ID as its EEPROM schema marker. Keep
# these stable across compatible releases; change one only when that target's
# Vial EEPROM layout becomes intentionally incompatible.
$vialBuildIds = @{
    xtips   = '0x009E59BD'
    szrkbd  = '0x009F2180'
    foostan = '0x0012F400'
}

function Assert-PinnedRepository {
    param([string] $Path, [string] $Expected)
    if (-not (Test-Path -LiteralPath (Join-Path $Path '.git'))) {
        throw "Missing $Path. Run tools/bootstrap.ps1 first."
    }
    $actual = git -c "safe.directory=$($Path -replace '\\','/')" -C $Path rev-parse HEAD
    if ($LASTEXITCODE -ne 0 -or $actual.Trim() -ne $Expected) {
        throw "Unexpected revision in $Path. Expected $Expected, found $actual."
    }
}

function Remove-SafeBuildDirectory {
    param([string] $Path, [string] $AllowedRoot)
    if (-not (Test-Path -LiteralPath $Path)) { return }
    $resolvedPath = [IO.Path]::GetFullPath($Path)
    $resolvedRoot = [IO.Path]::GetFullPath($AllowedRoot).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    if (-not $resolvedPath.StartsWith($resolvedRoot, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to remove path outside the build root: $resolvedPath"
    }
    Remove-Item -LiteralPath $resolvedPath -Recurse -Force
}

function Copy-FreshDirectory {
    param([string] $Source, [string] $Destination, [string] $AllowedRoot)
    Remove-SafeBuildDirectory -Path $Destination -AllowedRoot $AllowedRoot
    New-Item -ItemType Directory -Force -Path $Destination | Out-Null
    Copy-Item -Path (Join-Path $Source '*') -Destination $Destination -Recurse -Force
}

function Apply-VialPatch {
    param([string] $QmkRoot)
    if (Select-String -LiteralPath (Join-Path $QmkRoot 'quantum\vialrgb.h') -Pattern 'vialrgb_allow_write_kb' -Quiet) { return }
    git -c "safe.directory=$($QmkRoot -replace '\\','/')" -C $QmkRoot apply --check $vialPatch
    if ($LASTEXITCODE -ne 0) { throw "The VialRGB policy patch does not apply cleanly to $QmkRoot" }
    git -c "safe.directory=$($QmkRoot -replace '\\','/')" -C $QmkRoot apply $vialPatch
    if ($LASTEXITCODE -ne 0) { throw "Failed to apply the VialRGB policy patch to $QmkRoot" }
}

function Apply-TapDancePatch {
    param([string] $QmkRoot)
    if (Select-String -LiteralPath (Join-Path $QmkRoot 'quantum\vial.c') -Pattern 'vial_tap_dance_reliable_interrupt_kb' -Quiet) { return }
    git -c "safe.directory=$($QmkRoot -replace '\\','/')" -C $QmkRoot apply --check $tapDancePatch
    if ($LASTEXITCODE -ne 0) { throw "The reliable Tap Dance patch does not apply cleanly to $QmkRoot" }
    git -c "safe.directory=$($QmkRoot -replace '\\','/')" -C $QmkRoot apply $tapDancePatch
    if ($LASTEXITCODE -ne 0) { throw "Failed to apply the reliable Tap Dance patch to $QmkRoot" }
}

function Apply-TapDanceDelayPatch {
    param([string] $QmkRoot)
    if (Select-String -LiteralPath (Join-Path $QmkRoot 'quantum\vial.c') -Pattern 'vial_tap_dance_effective_delay_kb' -Quiet) { return }
    git -c "safe.directory=$($QmkRoot -replace '\\','/')" -C $QmkRoot apply --check $tapDanceDelayPatch
    if ($LASTEXITCODE -ne 0) { throw "The Tap Dance minimum-delay patch does not apply cleanly to $QmkRoot" }
    git -c "safe.directory=$($QmkRoot -replace '\\','/')" -C $QmkRoot apply $tapDanceDelayPatch
    if ($LASTEXITCODE -ne 0) { throw "Failed to apply the Tap Dance minimum-delay patch to $QmkRoot" }
}

function Apply-StableBuildIdPatch {
    param([string] $QmkRoot)
    if (Select-String -LiteralPath (Join-Path $QmkRoot 'util\build_id.py') -Pattern 'VIAL_BUILD_ID' -Quiet) { return }
    git -c "safe.directory=$($QmkRoot -replace '\\','/')" -C $QmkRoot apply --check $stableBuildIdPatch
    if ($LASTEXITCODE -ne 0) { throw "The stable Vial build-ID patch does not apply cleanly to $QmkRoot" }
    git -c "safe.directory=$($QmkRoot -replace '\\','/')" -C $QmkRoot apply $stableBuildIdPatch
    if ($LASTEXITCODE -ne 0) { throw "Failed to apply the stable Vial build-ID patch to $QmkRoot" }
}

function Install-KeymapOverlay {
    param([string] $BaseKeymap, [string] $Overlay, [string] $Destination, [string] $AllowedRoot)
    Copy-FreshDirectory -Source $BaseKeymap -Destination $Destination -AllowedRoot $AllowedRoot
    Copy-Item -Path (Join-Path $Overlay '*') -Destination $Destination -Recurse -Force
    Copy-Item -Path (Join-Path $commonRoot '*') -Destination $Destination -Force
}

function Invoke-QmkCompile {
    param([string] $QmkRoot, [string] $Keyboard, [string] $Keymap, [string] $VialBuildId)
    $qmk = 'C:\QMK_MSYS\mingw64\bin\qmk.exe'
    if (-not (Test-Path -LiteralPath $qmk)) { throw "QMK executable not found at $qmk" }
    $previousBuildId = $env:VIAL_BUILD_ID
    Push-Location $QmkRoot
    try {
        $env:MSYSTEM = 'MINGW64'
        $env:CHERE_INVOKING = '1'
        $env:SHELL = 'C:\QMK_MSYS\usr\bin\bash.exe'
        $env:PATH = 'C:\QMK_MSYS\mingw64\bin;C:\QMK_MSYS\usr\bin;' + $env:PATH
        $env:VIAL_BUILD_ID = $VialBuildId
        & $qmk compile -kb $Keyboard -km $Keymap
        if ($LASTEXITCODE -ne 0) { throw "QMK build failed for ${Keyboard}:$Keymap" }
    } finally {
        $env:VIAL_BUILD_ID = $previousBuildId
        Pop-Location
    }
}

function Copy-NewestArtifact {
    param(
        [string] $QmkRoot,
        [string] $Pattern,
        [string] $DestinationName,
        [ValidateSet('xtips-bin', 'rp2040-uf2')]
        [string] $StorageGuard
    )
    $artifact = Get-ChildItem -LiteralPath (Join-Path $QmkRoot '.build') -File | Where-Object Name -Like $Pattern | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $artifact) { throw "No build artifact matching $Pattern was produced." }
    if ($StorageGuard -eq 'xtips-bin') { Assert-XtipsFirmwarePreservesEeprom -Path $artifact.FullName }
    if ($StorageGuard -eq 'rp2040-uf2') { Assert-Rp2040Uf2PreservesEeprom -Path $artifact.FullName }
    New-Item -ItemType Directory -Force -Path $distRoot | Out-Null
    Copy-Item -LiteralPath $artifact.FullName -Destination (Join-Path $distRoot $DestinationName) -Force
}

function Build-Xtips {
    $qmkRoot = Join-Path $vendorRoot 'vial-qmk'
    $sourceRoot = Join-Path $vendorRoot 'xtips-qmk'
    Assert-PinnedRepository -Path $qmkRoot -Expected $lock.vialQmk.commit
    Assert-PinnedRepository -Path $sourceRoot -Expected $lock.xtipsQmkKeyboard.commit
    Apply-VialPatch -QmkRoot $qmkRoot
    Apply-TapDancePatch -QmkRoot $qmkRoot
    Apply-TapDanceDelayPatch -QmkRoot $qmkRoot
    Apply-StableBuildIdPatch -QmkRoot $qmkRoot

    $keyboardDestination = Join-Path $qmkRoot 'keyboards\xtips\v4s'
    Copy-FreshDirectory -Source (Join-Path $sourceRoot 'v4s') -Destination $keyboardDestination -AllowedRoot (Join-Path $qmkRoot 'keyboards')
    Install-KeymapOverlay -BaseKeymap (Join-Path $sourceRoot 'v4s\keymaps\vial') -Overlay (Join-Path $projectRoot 'firmware\xtips_v4s_103c') -Destination (Join-Path $keyboardDestination 'keymaps\corne_control') -AllowedRoot (Join-Path $qmkRoot 'keyboards')

    Invoke-QmkCompile -QmkRoot $qmkRoot -Keyboard 'xtips/v4s/103c' -Keymap 'corne_control' -VialBuildId $vialBuildIds.xtips
    Copy-NewestArtifact -QmkRoot $qmkRoot -Pattern '*xtips*v4s*103c*corne_control*.bin' -DestinationName 'xtips-v4s-103c-corne-control.bin' -StorageGuard 'xtips-bin'
}

function Build-Rp2040Corne {
    param(
        [string] $OverlayName,
        [string] $KeymapName,
        [string] $ArtifactName,
        [string] $VialBuildId
    )
    $foostanRoot = Join-Path $vendorRoot 'foostan-kbd-firmware'
    $qmkRoot = Join-Path $foostanRoot 'src\vial-kb\vial-qmk'
    Assert-PinnedRepository -Path $foostanRoot -Expected $lock.foostanKeyboardFirmware.commit
    Assert-PinnedRepository -Path $qmkRoot -Expected $lock.foostanKeyboardFirmware.vialQmkCommit
    Apply-VialPatch -QmkRoot $qmkRoot
    Apply-TapDancePatch -QmkRoot $qmkRoot
    Apply-TapDanceDelayPatch -QmkRoot $qmkRoot
    Apply-StableBuildIdPatch -QmkRoot $qmkRoot

    $keyboardDestination = Join-Path $qmkRoot 'keyboards\tmp\crkbd'
    Copy-FreshDirectory -Source (Join-Path $foostanRoot 'keyboards\crkbd\qmk\qmk_firmware') -Destination $keyboardDestination -AllowedRoot (Join-Path $qmkRoot 'keyboards')
    $keymapsDestination = Join-Path $keyboardDestination 'keymaps'
    Copy-FreshDirectory -Source (Join-Path $foostanRoot 'keyboards\crkbd\vial-kb\vial-qmk\keymaps') -Destination $keymapsDestination -AllowedRoot (Join-Path $qmkRoot 'keyboards')
    Install-KeymapOverlay -BaseKeymap (Join-Path $keymapsDestination 'vial') -Overlay (Join-Path $projectRoot "firmware\$OverlayName") -Destination (Join-Path $keymapsDestination $KeymapName) -AllowedRoot (Join-Path $qmkRoot 'keyboards')

    Invoke-QmkCompile -QmkRoot $qmkRoot -Keyboard 'tmp/crkbd/rev4_1/standard' -Keymap $KeymapName -VialBuildId $VialBuildId
    Copy-NewestArtifact -QmkRoot $qmkRoot -Pattern "*tmp*crkbd*rev4_1*standard*$KeymapName*.uf2" -DestinationName $ArtifactName -StorageGuard 'rp2040-uf2'
}

function Build-Szrkbd {
    Build-Rp2040Corne -OverlayName 'szrkbd_corne_v4_1' -KeymapName 'corne_control_szrkbd' -ArtifactName 'szrkbd-corne-v4.1-corne-control.uf2' -VialBuildId $vialBuildIds.szrkbd
}

function Build-Foostan {
    Build-Rp2040Corne -OverlayName 'foostan_corne_v4_1' -KeymapName 'corne_control_foostan' -ArtifactName 'foostan-corne-v4.1-corne-control.uf2' -VialBuildId $vialBuildIds.foostan
}

if ($Target -in @('all', 'xtips')) { Build-Xtips }
if ($Target -in @('all', 'szrkbd')) { Build-Szrkbd }
if ($Target -in @('all', 'foostan')) { Build-Foostan }

Write-Host "Build complete. Artifacts are in $distRoot"
