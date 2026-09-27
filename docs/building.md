# Reproducible builds

This page covers compiling firmware from source. If you only want to install
the ready-made files, follow [Initial flashing](flashing.md), which includes
copy-paste commands for Windows and Linux.

## Requirements

- Windows PowerShell
- Git
- QMK MSYS installed at `C:\QMK_MSYS`
- Internet access for the first bootstrap

## Bootstrap

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/bootstrap.ps1
```

The script checks out the exact revisions in `upstream.lock.json` and initializes their QMK submodules under ignored `.build/vendor/`.

## Compile

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/build.ps1 -Target all
```

The build script:

1. verifies every pinned commit;
2. applies the VialRGB ownership/direct-update hook if absent;
3. applies the stable Vial EEPROM build-ID patch;
4. stages the manufacturer hardware definition and this repository's keymap overlay;
5. compiles each target with its pinned EEPROM schema ID;
6. rejects any image whose programmed range could overlap emulated EEPROM;
7. copies board-named artifacts to ignored `dist/`.

The IDs in `tools/build.ps1` are storage-schema versions, not release numbers.
Do not change one merely because firmware code changed. Change only the affected
target's ID when its Vial EEPROM layout becomes incompatible, and document the
resulting one-time reset.

After all builds succeed, update the firmware and manifest served by GitHub Pages:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/package-web.ps1
```

Packaging verifies the pinned WebDFU source, copies the three artifacts into `webhid/firmware/`, and records their exact sizes and SHA-256 hashes in `manifest.json`.
It repeats the persistent-storage boundary checks before publishing. See
[Persistent settings](persistence.md) for the protected ranges.

The source checkouts are disposable build inputs. Tracked source lives in `firmware/`, `patches/`, `tools/`, and `webhid/`.

## Current verified compile results

| Target | Upstream QMK target | Result |
| --- | --- | --- |
| XTIPS | `xtips/v4s/103c:corne_control` | `.bin`, 48,136 bytes (48,120-byte QMK payload) |
| SZRKBD | `tmp/crkbd/rev4_1/standard:corne_control_szrkbd` | `.uf2`, 133,632 bytes |
| foostan v4.1 standard | `tmp/crkbd/rev4_1/standard:corne_control_foostan` | `.uf2`, 133,632 bytes |

Compile success does not authorize flashing a target whose physical wiring has not been verified. In particular, the SZRKBD artifact remains provisional.
