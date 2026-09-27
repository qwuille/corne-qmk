# Initial flashing

Corne Control must be flashed once before the WebHID control deck can connect.
These instructions use the ready-made firmware files committed under
`webhid/firmware/`; compiling the project first is not required.

## Preserving the current layout

Later updates made with the commands on this page preserve the keyboard's
emulated EEPROM: Vial layers, macros, combos, Tap Dance, saved RGB settings,
and Corne Control ownership remain in place. Do not perform a mass erase or an
EEPROM reset. Before the first conversion from factory firmware, and before a
major update, export a Vial `.vil` backup anyway. See
[Persistent settings](persistence.md) for storage boundaries and exceptions.

## Before flashing either keyboard

1. Disconnect USB and disconnect the cable between the two keyboard halves.
2. Connect only the half you are flashing to the computer.
3. Flash the correct firmware for that keyboard.
4. Disconnect and test that half, then repeat the same procedure on the other
   half. Both halves need the same board-specific firmware.

Never connect joined halves to two USB hosts. Keep the XTIPS factory readbacks
and your Vial `.vil` backup until both halves have been tested.

## XTIPS V4s / 103C (STM32 DFU)

Use this file:

```text
webhid/firmware/xtips-v4s-103c-corne-control.bin
```

The XTIPS bootloader identifies as `1EAF:0003`. The application must be written
to DFU alternate interface 2, beginning at `0x08002000`. Do not use alternate 0
or 1.

### Windows

Windows requires the **dfu-util** command-line utility and a suitable USB
driver. The easiest project-supported setup is QMK MSYS, which supplies both:

- Install QMK MSYS if it is not already installed.
- Run `C:\QMK_MSYS\qmk_driver_installer.exe` once as Administrator.
- The bundled command is normally
  `C:\QMK_MSYS\opt\qmk\bin\dfu-util.exe`.

From PowerShell in the repository root, first check that dfu-util exists:

```powershell
$dfu = 'C:\QMK_MSYS\opt\qmk\bin\dfu-util.exe'
if (-not (Test-Path -LiteralPath $dfu)) {
    throw 'dfu-util was not found. Install QMK MSYS or update $dfu to your dfu-util.exe path.'
}
& $dfu --version
```

Put one isolated XTIPS half into bootloader mode. Confirm that dfu-util sees the
STM32duino bootloader before writing:

```powershell
& $dfu -d 1EAF:0003 -l
```

Flash that half:

```powershell
& $dfu `
    -d 1EAF:0003 `
    -a 2 `
    -D '.\webhid\firmware\xtips-v4s-103c-corne-control.bin' `
    -R
```

Wait for the command to finish and the controller to reset. Disconnect it,
then repeat the bootloader and flash steps for the other isolated half.

If dfu-util reports `No DFU capable USB device available`, confirm that the
half is in bootloader mode and rerun the QMK driver installer.

### Linux

Install dfu-util. On Debian or Ubuntu:

```bash
sudo apt update
sudo apt install dfu-util
```

Equivalent package commands include `sudo dnf install dfu-util` on Fedora and
`sudo pacman -S dfu-util` on Arch Linux.

Put one isolated XTIPS half into bootloader mode, then confirm that it appears:

```bash
sudo dfu-util -d 1eaf:0003 -l
```

Flash it from the repository root:

```bash
sudo dfu-util \
  -d 1eaf:0003 \
  -a 2 \
  -D ./webhid/firmware/xtips-v4s-103c-corne-control.bin \
  -R
```

Wait for the controller to reset, disconnect it, and repeat for the other
isolated half. `sudo` is normally unnecessary after installing an appropriate
udev rule for the STM32duino bootloader.

## SZRKBD or original foostan Corne v4.1 (RP2040 UF2)

RP2040 does not use dfu-util. Its built-in BOOTSEL loader appears as a removable
drive named `RPI-RP2`. Choose the correct file:

| Keyboard | Firmware file |
| --- | --- |
| SZRKBD Corne v4.1 | `webhid/firmware/szrkbd-corne-v4.1-corne-control.uf2` |
| Original foostan Corne v4.1 standard | `webhid/firmware/foostan-corne-v4.1-corne-control.uf2` |

The generic `RPI-RP2` loader cannot detect which PCB surrounds the RP2040, so
you must choose the model yourself. The SZRKBD firmware remains provisional
until that clone's GPIO wiring has been physically verified.

### Windows

Hold BOOTSEL while connecting one isolated half, or invoke `QK_BOOT` from
working firmware. Confirm that an `RPI-RP2` drive appears.

From PowerShell in the repository root, select exactly one firmware line:

```powershell
# SZRKBD:
$firmware = Resolve-Path '.\webhid\firmware\szrkbd-corne-v4.1-corne-control.uf2'

# Original foostan (use this instead for the original board):
# $firmware = Resolve-Path '.\webhid\firmware\foostan-corne-v4.1-corne-control.uf2'

$rpVolumes = @(Get-Volume -FileSystemLabel 'RPI-RP2')
if ($rpVolumes.Count -ne 1) {
    throw "Expected exactly one RPI-RP2 drive, found $($rpVolumes.Count)."
}

$destination = "$($rpVolumes[0].DriveLetter):\"
Copy-Item -LiteralPath $firmware.Path -Destination $destination
```

The `RPI-RP2` drive disappears automatically after accepting the UF2. Wait for
the keyboard to reboot, disconnect it, and repeat for the other isolated half.

### Linux

Hold BOOTSEL while connecting one isolated half, or invoke `QK_BOOT` from
working firmware. Most desktop distributions automatically mount `RPI-RP2`.
If it is not mounted, use the file manager or run:

```bash
udisksctl mount -b /dev/disk/by-label/RPI-RP2
```

From a terminal in the repository root, select the correct firmware and copy
it to the mounted bootloader drive:

```bash
# SZRKBD:
firmware='./webhid/firmware/szrkbd-corne-v4.1-corne-control.uf2'

# Original foostan (use this instead for the original board):
# firmware='./webhid/firmware/foostan-corne-v4.1-corne-control.uf2'

rp_mount="$(findmnt -rn -S LABEL=RPI-RP2 -o TARGET)"
if [ -z "$rp_mount" ]; then
  echo 'RPI-RP2 is not mounted.' >&2
  exit 1
fi

cp -- "$firmware" "$rp_mount/"
```

The drive disappears when the RP2040 accepts the UF2 and reboots. Disconnect
the half and repeat the same procedure for the other isolated half.

## Integrated browser flasher

The same files can be flashed from the **Firmware update** section of
`webhid/index.html` in current Chrome or Edge. Use the hosted GitHub Pages
version, or serve the directory locally:

```text
https://qwuille.github.io/corne-qmk/#firmware
```

```powershell
python -m http.server 8000 --directory webhid
```

Then open `http://localhost:8000/#firmware`. The browser verifies the
selected firmware before writing it. If WebUSB or folder access is unavailable,
use the command-line instructions above.

## After installation

Open the Corne Control page and click **Connect**, then select the Vial Raw HID
interface. The firmware-reported board ID, not USB VID:PID alone, selects the
correct keyboard representation. Use Vial separately for layouts, macros,
combos, and Tap Dance.
