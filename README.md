# Corne Control firmware

Vial firmware, OpenRGB support, an initial web flasher, and a board-aware WebHID control deck for three 3x6 Corne-family keyboards:

- **XTIPS V4s / PCB `V4A-R2.1`** with Geehy APM32F103C8T6 and one RGB LED beneath each of `F` and `J`.
- **SZRKBD Corne-compatible v4.1** with RP2040 and 46 per-key RGB LEDs, provisionally based on foostan's `crkbd/rev4_1/standard` definition.
- **Original foostan Corne v4.1 standard** with RP2040 and the published 46-LED hardware definition.

The targets share behavior, not hardware declarations. Never flash one board's artifact onto the other.

## Implemented features

- Vial dynamic keymaps.
- Vial Tap Dance with a persistent WebHID reliable-typing mode for interrupted dances.
- VialRGB/OpenRGB through the existing 32-byte Vial Raw HID interface.
- Persistent Firmware/OpenRGB lighting ownership.
- Direct OpenRGB color forwarding from the USB master to whichever physical half is secondary.
- RGB shutdown on normal USB suspend and when the host is no longer configured, covering PCs that retain USB standby power after shutdown.
- Hardware-timed PWM/DMA WS2812 output on XTIPS, verified to eliminate APM32 LED flicker.
- A versioned WebHID protocol and one control deck for all three firmware identities.
- Direct, EEPROM-safe live RGB preview from the WebHID controls, with an explicit save action.
- Reflash-persistent Vial and Corne Control settings, with artifact guards that prevent firmware from overlapping emulated EEPROM.
- Live layer, Caps Lock, Num Lock, Scroll Lock, split-role, and RGB suspend status.
- CSS-only keyboard maps with animated RGB frames on the physical LED-equipped keys; no image assets are required.
- WebHID JSON export/import, kept separate from Vial's `.vil` layout backup.

## Build

Windows with QMK MSYS installed:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/bootstrap.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tools/build.ps1 -Target all
```

Individual targets:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/build.ps1 -Target xtips
powershell -NoProfile -ExecutionPolicy Bypass -File tools/build.ps1 -Target szrkbd
powershell -NoProfile -ExecutionPolicy Bypass -File tools/build.ps1 -Target foostan
```

Artifacts are written to ignored `dist/`:

| Artifact | Install method | Status |
| --- | --- | --- |
| `xtips-v4s-103c-corne-control.bin` | STM32duino DFU, alternate interface 2 | Compiles; physical test required before release |
| `szrkbd-corne-v4.1-corne-control.uf2` | Copy to `RPI-RP2` | Compiles; **do not flash until the clone's pinout is verified** |
| `foostan-corne-v4.1-corne-control.uf2` | Copy to `RPI-RP2` | Compiles against the original foostan v4.1 standard target |

Run `tools/package-web.ps1` after compiling to refresh the hash-verified firmware files used by the web flasher. Upstream revisions are pinned in `upstream.lock.json`; disposable build trees, `dist/`, backups, and private local state are ignored by Git.

## WebHID

Serve `webhid/` from localhost or HTTPS and open it in Chrome or Edge. For example:

```powershell
python -m http.server 8000 --directory webhid
```

Then open `http://localhost:8000`. Use **Initial flash** before the control deck when the keyboard still runs factory firmware. The page accepts only the Vial Raw HID collection for these USB identities:

| Board | VID:PID | OpenRGB pixels |
| --- | --- | --- |
| XTIPS V4s/103C | `5262:4E4B` | 2, positioned at F and J |
| SZRKBD Corne v4.1 | `4653:0004` | 46, 23 per half |
| foostan Corne v4.1 standard | `4653:0004` | 46, 23 per half |

Use Vial for keymaps, macros, combos, and Tap Dance. Use Corne Control for lighting ownership and board-specific status. See [initial flashing](docs/flashing.md), [persistent settings](docs/persistence.md), [the protocol](webhid/PROTOCOL.md), and [OpenRGB setup](docs/openrgb.md).

## Safety

- Flash the same board-specific artifact onto both controllers, one half at a time.
- Remove computer power before rearranging the inter-half connection.
- Do not connect linked halves to two USB hosts simultaneously.
- Keep the private factory readbacks and Vial export until both custom-firmware halves have passed cold-boot, split, encoder, RGB, suspend, and wake testing.
- The SZRKBD target remains provisional: `RPI-RP2` confirms RP2040, but not the GPIO mapping.

## License and attribution

Copyright (C) 2026 Qwuille.

Original project code, browser tooling, and documentation are licensed under
GNU GPL version 3 or later. Firmware files integrated with QMK are marked
GPL-2.0-or-later. Third-party components retain their own licenses and
copyright notices; see [third-party notices](webhid/THIRD_PARTY_NOTICES.md).
