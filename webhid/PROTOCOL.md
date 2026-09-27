# Corne Control WebHID protocol

Corne Control uses the existing 32-byte Vial Raw HID collection (usage page `0xFF60`, usage `0x61`). It does not add another USB interface. Command byte `0x72` is reserved for this project.

Every request and reply is 32 bytes:

| Byte | Meaning |
| --- | --- |
| 0 | `0x72` command prefix |
| 1 | operation |
| 2 | reply status: `0` success, `1` bad length, `2` unknown operation, `3` invalid value |
| 3-31 | operation payload |

## Operations

### `0x00` — Get information

Reply payload:

| Byte | Meaning |
| --- | --- |
| 3-4 | protocol major and minor |
| 5 | board: `1` XTIPS V4s/103C, `2` SZRKBD Corne v4.1, `3` foostan Corne v4.1 standard |
| 6 | capability bitmap |
| 7-8 | little-endian total RGB LED count |
| 9 | LEDs on the left half |
| 10 | maximum brightness |
| 11 | Vial dynamic layer count |
| 12 | number of portable firmware effects |

### `0x01` / `0x02` — Get/set lighting

| Byte | Meaning |
| --- | --- |
| 3 | owner: `0` firmware, `1` OpenRGB |
| 4 | enabled |
| 5 | effect: solid, breathing, rainbow, hue wave, reactive |
| 6 | hue |
| 7 | saturation |
| 8 | brightness |
| 9 | speed |
| 10 | get-only suspend state |

OpenRGB writes are accepted only while owner `1` is stored. Firmware RGB configuration remains in QMK EEPROM and is restored when ownership returns to firmware.

### `0x03` — Get live status

Byte 3 is the highest active layer, byte 4 is the USB host LED bitmask, byte 5 reports the USB-master role, and byte 6 reports RGB suspend state.

### `0x04` — Configuration heartbeat

WebHID sends a heartbeat while connected. VialRGB writes are paused until five seconds after the last Corne Control request so WebHID and OpenRGB cannot fight over the shared HID endpoint.

## Split RGB forwarding

VialRGB direct packets arrive only at the USB master. The core patch calls a board hook after each direct packet. Corne Control queues the portion belonging to the secondary half and forwards up to nine HSV pixels per QMK user transaction (`CORNE_RGB_SYNC`). This fits QMK's default 32-byte master-to-secondary RPC buffer.

## Suspend and shutdown

`RGB_MATRIX_SLEEP` handles normal USB suspend. Corne Control additionally observes USB device state and forces RGB Matrix into its suspended state whenever the device is no longer configured. This clears a latched OpenRGB frame during host shutdowns that retain USB standby power.
