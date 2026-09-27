# Initial flashing

The control deck cannot connect until Corne Control firmware has been installed. Factory Vial firmware may expose the same Raw HID collection, but it does not implement command `0x72`.

Serve `webhid/` through HTTPS or localhost and open `flasher.html` in current Chrome or Edge:

```powershell
python -m http.server 8000 --directory webhid
```

Open `http://localhost:8000/flasher.html`.

## Safety rules for every split keyboard

1. Disconnect the inter-half cable.
2. Connect only the half being flashed directly to the computer.
3. Select the exact keyboard model.
4. Flash and test that half before repeating with the other half.
5. Use the same board-specific artifact on both halves.

Never connect the linked halves to two USB hosts simultaneously. Keep the XTIPS factory readbacks and Vial `.vil` backup until both halves pass testing.

## XTIPS V4s / 103C

The XTIPS uses the STM32duino DFU bootloader at USB `1EAF:0003`. Its firmware must be written to alternate interface 2, which begins at `0x08002000`.

1. Isolate one half and enter its bootloader.
2. In the flasher, click **Connect bootloader** and select the STM32duino device.
3. Confirm the safety checkbox and click **Flash XTIPS through WebUSB**.
4. Wait for verification, transfer, manifestation, and reset to finish.
5. Test the half before repeating with the other half.

The page checks the firmware size, SHA-256, vector table, USB identity, DFU protocol, and alternate-interface number before writing. If the operating system does not expose STM32duino DFU to WebUSB, download the verified `.bin` from the same page and use QMK's standard command:

```powershell
& 'C:\QMK_MSYS\opt\qmk\bin\dfu-util.exe' `
    -d 1EAF:0003 `
    -a 2 `
    -D '.\dist\xtips-v4s-103c-corne-control.bin' `
    -R
```

Run this from the repository root after placing one isolated XTIPS half in bootloader mode. `-d 1EAF:0003` restricts the command to the STM32duino bootloader, `-a 2` selects the application region beginning at `0x08002000`, `-D` downloads the binary, and `-R` resets the controller afterward. Do not use alternate 0 or 1.

To confirm the bootloader before writing:

```powershell
& 'C:\QMK_MSYS\opt\qmk\bin\dfu-util.exe' -d 1EAF:0003 -l
```

## SZRKBD and original foostan Corne v4.1

Both RP2040 boards use the immutable BOOTSEL UF2 loader. It appears as a drive named `RPI-RP2`; the bootloader itself cannot identify whether the surrounding PCB is SZRKBD or an original foostan Corne.

1. Explicitly select **SZRKBD Corne v4.1** or **foostan Corne v4.1 standard** in the flasher.
2. Isolate one half and enter BOOTSEL mode by holding BOOTSEL while connecting USB, or use `QK_BOOT` from working firmware.
3. Click **Copy UF2 to RPI-RP2** and select the root of the `RPI-RP2` drive.
4. The page checks `INFO_UF2.TXT`, verifies the UF2 and SHA-256, and copies the exact selected artifact.
5. The drive disappears when the controller accepts the image and reboots. Test the half before repeating.

If folder writing is unavailable in the browser, click **Download firmware** and manually copy the `.uf2` file to `RPI-RP2` using the operating system. The SZRKBD artifact remains provisional until that clone's wiring is physically verified.

No DFU command is needed for RP2040. On Windows, the following PowerShell example refuses to continue unless exactly one `RPI-RP2` volume is mounted:

```powershell
$rpVolumes = @(Get-Volume -FileSystemLabel 'RPI-RP2')
if ($rpVolumes.Count -ne 1) {
    throw "Expected one RPI-RP2 drive, found $($rpVolumes.Count)."
}

$rpDestination = "$($rpVolumes[0].DriveLetter):\"
Copy-Item -LiteralPath '.\dist\foostan-corne-v4.1-corne-control.uf2' `
    -Destination $rpDestination
```

For SZRKBD, replace the source filename with `szrkbd-corne-v4.1-corne-control.uf2`. Copying a valid UF2 makes the controller program itself, disconnect the `RPI-RP2` drive, and reboot into the new firmware. Flash the two isolated halves separately.

## After installation

Open `index.html`, click **Connect**, and select the Vial Raw HID interface. The firmware-reported board ID—not USB VID:PID alone—selects the correct keyboard representation. Use Vial separately for layouts, macros, combos, and Tap Dance.
