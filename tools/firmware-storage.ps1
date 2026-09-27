# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Qwuille

$XtTipsApplicationMaximumBytes = 0xC000
$Rp2040EepromStartAddress = 0x101FE000

function Assert-XtipsFirmwarePreservesEeprom {
    param([Parameter(Mandatory)][string] $Path)

    $item = Get-Item -LiteralPath $Path
    if ($item.Length -gt $XtTipsApplicationMaximumBytes) {
        throw ('XTIPS firmware is {0} bytes; the maximum before emulated EEPROM is {1} bytes. Refusing an image that can overwrite persistent settings.' -f $item.Length, $XtTipsApplicationMaximumBytes)
    }

    Write-Host ('XTIPS persistent-storage guard: {0} bytes free before EEPROM.' -f ($XtTipsApplicationMaximumBytes - $item.Length))
}

function Assert-Rp2040Uf2PreservesEeprom {
    param([Parameter(Mandatory)][string] $Path)

    $bytes = [IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $Path))
    if ($bytes.Length -eq 0 -or $bytes.Length % 512 -ne 0) {
        throw "Invalid UF2 length for $Path."
    }

    $highestEnd = [uint64]0
    for ($offset = 0; $offset -lt $bytes.Length; $offset += 512) {
        $magic0 = [BitConverter]::ToUInt32($bytes, $offset)
        $magic1 = [BitConverter]::ToUInt32($bytes, $offset + 4)
        $magicEnd = [BitConverter]::ToUInt32($bytes, $offset + 508)
        if ($magic0 -ne 0x0A324655 -or $magic1 -ne [uint32]2656915799 -or $magicEnd -ne 0x0AB16F30) {
            throw "Invalid UF2 block at byte offset $offset in $Path."
        }

        $flags = [BitConverter]::ToUInt32($bytes, $offset + 8)
        if (($flags -band 0x1) -ne 0) { continue }

        $target = [uint64][BitConverter]::ToUInt32($bytes, $offset + 12)
        $payloadSize = [uint64][BitConverter]::ToUInt32($bytes, $offset + 16)
        if ($payloadSize -gt 476) {
            throw "Invalid UF2 payload size $payloadSize at byte offset $offset in $Path."
        }

        $blockEnd = $target + $payloadSize
        if ($blockEnd -gt $highestEnd) { $highestEnd = $blockEnd }
        if ($target -ge $Rp2040EepromStartAddress -or $blockEnd -gt $Rp2040EepromStartAddress) {
            throw ('UF2 block 0x{0:X8}-0x{1:X8} overlaps RP2040 emulated EEPROM at 0x{2:X8}. Refusing an image that can overwrite persistent settings.' -f $target, $blockEnd, $Rp2040EepromStartAddress)
        }
    }

    Write-Host ('RP2040 persistent-storage guard: highest UF2 address 0x{0:X8}; EEPROM begins at 0x{1:X8}.' -f $highestEnd, $Rp2040EepromStartAddress)
}
