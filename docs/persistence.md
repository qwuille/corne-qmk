# Persistent settings

Corne Control keeps configuration outside the firmware image. A normal update
with the documented DFU or UF2 procedure therefore preserves settings when the
same board target and compatible storage schema are used.

The persistent data includes:

- Vial layers and key assignments;
- macros, combos, Tap Dance entries, and encoder mappings;
- saved QMK RGB Matrix settings;
- the Corne Control Firmware/OpenRGB owner setting;
- the reliable Tap Dance typing-interrupt setting.

WebHID lighting changes are first previewed in RAM. Click **Save lighting** to
write the selected effect, hue, saturation, brightness, and speed to persistent
storage. Vial configuration changes are written persistently by Vial itself.
Click **Save typing behavior** to persist reliable Tap Dance interruption; this
small Corne Control setting is also synchronized to the connected secondary
half.

## Protected flash regions

The XTIPS APM32F103C8T6 build starts at `0x08002000`. Its final 8 KiB,
`0x0800E000` through `0x0800FFFF`, is reserved for QMK's wear-levelled EEPROM.
The build and packaging scripts reject a `.bin` larger than 49,152 bytes so an
update cannot extend into that area.

The RP2040 builds reserve the final 8 KiB of their 2 MiB flash for the same
purpose. That region starts at XIP address `0x101FE000`. Every UF2 block is
checked during building and packaging; an artifact that reaches the reserved
region is rejected.

These checks protect settings from this project's release artifacts. They do
not make storage indestructible.

## Stable Vial storage schema

Stock Vial generates a random build ID during each clean compilation and uses
its low 24 bits as the EEPROM-validity marker. That normally resets the dynamic
keymap after installing a newly compiled image even when the EEPROM flash pages
were preserved.

This project pins one build ID per target. Compatible releases retain that ID,
so normal reflashes preserve Vial layers, macros, combos, and Tap Dance entries.
The build IDs are intentionally changed only when an EEPROM-layout change is
incompatible and retaining the old data would be unsafe. The first transition
from factory firmware or an older build with a different ID can still reset the
layout; export a Vial `.vil` file before that transition.

## Operations that can erase settings

- a full-chip or mass erase;
- an EEPROM-clear/Bootmagic reset;
- flashing an image that deliberately covers the entire flash device;
- changing to firmware with an incompatible Vial UID, build ID, or EEPROM layout;
- replacing a controller.

Use the documented XTIPS DFU alternate 2 command or copy the board-specific
UF2 to `RPI-RP2`; do not add a mass-erase option. Keep a Vial `.vil` export as
the portable recovery copy before an initial installation or major update.
Corne Control's JSON export covers its own lighting, ownership, and typing-behavior settings, not
the Vial keymap database.

## Split-keyboard detail

Each half has its own controller and physical flash. Configuration is read
from whichever half is the USB master. If you sometimes connect the computer
to the other half, do not assume its entire Vial database was copied across
the split link: connect each half as master and import the same `.vil` file.
Flash both halves with the same board-specific firmware.
