# Hardware targets

## X.Tips V4s

Primary source: [X-Tips/QMK-Keyboard `v4s`](https://github.com/X-Tips/QMK-Keyboard/tree/main/v4s)

The manufacturer publishes a QMK/Vial hardware definition and a prebuilt `.bin`. The source currently declares:

| Property | Upstream value |
| --- | --- |
| QMK source target | `v4s/103c` |
| Product | X.Tips V4s.103 Keyboard |
| Physical MCU | Geehy APM32F103C8T6 |
| QMK processor target | STM32F103 |
| Bootloader | `stm32duino` |
| USB VID:PID | `5262:4E4B` |
| Matrix | Direct pins, 8 rows x 7 columns across the split |
| Split transport | USART serial, pin `B6` |
| Handedness | Pin `B7` |
| Encoders | One rotary encoder per half |
| Lighting | Two WS2812 LEDs, one per half, data pin `A9` / TIM1 channel 2 |
| Dynamic layers | 9 |
| Bootmagic | Hold `E` for the left half or `I` for the right half while connecting USB |

The upstream Vial keymap enables Vial and VIA, defines 64 macros and 80 combos, and uses `VIAL_INSECURE`. It does not define `VIAL_TAP_DANCE_ENTRIES`. The maintained target preserves those macro/combo capacities, allocates eight Tap Dance entries, and replaces insecure mode with the physical `Q` + `A` unlock combination.

The manufacturer's target is the starting point, but it should be imported with source attribution and tested against the physical board before flashing a modified image.

The physical MCU marking is Geehy `APM32F103C8T6`, not an ST-manufactured STM32F103. Geehy specifies an Arm Cortex-M3 core, 64 KB flash, 20 KB SRAM, USB, USART, I2C, and SPI for this part. It is an STM32F103-compatible implementation, and XTIPS intentionally builds it through QMK's `STM32F103` target. Preserve the upstream clock, bootloader, remap, and linker configuration until verified on hardware; do not assume the extra flash capacity sometimes associated with other F103-compatible parts.

The V4s is a 3x6 split with three thumb keys and two additional keys along the inner edge of each half (46 keys total). The upstream default assigns those four inner keys to editing shortcuts.

Lighting is limited to one RGB indicator LED on each half; this target must not inherit the SZRKBD full-key RGB topology. The maintained firmware uses the STM32 hardware PWM/DMA WS2812 driver because software bit-banging produced visible flicker on the physical APM32 clone. To remain within the 64 KB flash/storage boundary, XTIPS provides solid, breathing, and rainbow firmware effects plus VialRGB/OpenRGB; the RP2040 targets retain all five firmware effects.

The supplied link identifies the keyboard family as `v4s`. The current upstream source separates `v4s/103c` and `v4s/072c`; the physical APM32F103C8T6 selects `v4s/103c`. The other top-level folders (for example `v3s`, `v4e`, and `v4x`) are different keyboard models.

The physical PCB is marked `V4A-R2.1`, while the seller and Vial identify the product as V4s. The connected device reports USB VID:PID `5262:4E4B`, exactly matching the upstream definition, and that source folder contains both `v4a-*` and `v4s-*` reference photographs. Use `v4s/103c`; retain `V4A-R2.1` as the physical PCB revision until XTIPS documents the naming relationship explicitly.

The X-Tips repository supplies keyboard target files rather than a complete standalone QMK checkout. Build our maintained `v4s` target inside a pinned Vial-QMK tree, initially equivalent to:

```text
qmk compile -kb xtips/v4s/103c -km corne_control
```

The expected artifact format is `.bin` because the target uses the STM32duino bootloader.

The 64 KB device rating and STM32duino application boundary are release constraints. The current build reports 48,992 bytes and produces a 49,008-byte binary. The application begins at `0x08002000`, and the final 8 KiB beginning at `0x0800E000` is reserved for emulated EEPROM, leaving a maximum application-image size of 49,152 bytes. The automated guard reports 144 bytes of remaining image space and rejects any larger build rather than relying on undocumented extra flash.

The unused USB-C connector is located at the top of the XTIPS board. A display pod for this target should account for upward cable exit, connector strain relief, and clearance around the case and nearby keys.

### Split firmware and side identification

Each half has its own microcontroller and therefore needs firmware. The XTIPS target uses one identical `.bin` for both halves: its `SPLIT_HAND_PIN` on `B7` reads a hardware strap on each PCB to determine whether that controller is physically left or right. No separate left and right builds or EEPROM handedness files are required.

Left/right identity is separate from the runtime master/secondary role. Whichever half is connected to the computer becomes the USB master; the other half sends its key and encoder state over the split USART link. For a firmware release, flash the same verified image to both controllers, one half at a time. Remove computer power before moving or changing the inter-half cable, and never attach both halves to separate USB hosts at once.

Vial settings are written to persistent storage on the currently connected master and should not be assumed to mirror automatically into the other controller. If the computer cable will alternate between halves, load the same `.vil` configuration while each half is acting as master. Read-only per-controller flash dumps captured on 2026-09-26 showed that the factory contents of both halves, including their persistent regions, were byte-for-byte identical before modification.

## SZRKBD Corne-compatible board

The board is the 3x6 standard layout and is reported to follow foostan Corne v4.1 closely. In bootloader mode it presents the `RPI-RP2` USB mass-storage volume, identifying the MCU family as RP2040 and the firmware artifact format as UF2.

The physical SZRKBD has full RGB lighting on both halves. Verify LED count and ordering against the foostan v4.1 standard definition before enabling effects at full brightness.

This is strong evidence for the official `crkbd/rev4_1/standard` target as a starting point, but it does not prove matching GPIO assignments, split transport, handedness, or RGB wiring. Verify those details before flashing a newly compiled image.

Use [foostan/kbd_firmware](https://github.com/foostan/kbd_firmware), not the hardware-only `foostan/crkbd` repository, as the upstream firmware source. Foostan documents the Vial build as:

```text
kb=crkbd kr=rev4_1/standard km=vial make vial-qmk-compile
```

The expected artifact format is `.uf2`. Treat this target as provisional for SZRKBD until its key scanning, split link, handedness, and RGB behavior have been verified without hardware regressions.

The unused USB-C connector is near the inner edge, facing the opposite keyboard half. A display pod for this target should use inner-edge cable routing and must not obstruct normal separation or positioning of the halves.

The selected 3x6 physical board does not expose the display connection available on the 3x5 OLED arrangement. Treat the unused USB-C connector as its only external expansion interface.

## Original foostan Corne v4.1 standard

The original board uses the same `crkbd/rev4_1/standard` RP2040 hardware definition, `4653:0004` USB identity, 46-pixel RGB Matrix topology, and `RPI-RP2` UF2 bootloader used as the SZRKBD starting point. It is maintained as a separate release target so its published Vial UID and Corne Control board identity do not get conflated with the clone.

The foostan target is built directly from the pinned `foostan/kbd_firmware` wrapper and retains its published Vial UID. It produces `foostan-corne-v4.1-corne-control.uf2`. The same UF2 is installed on both halves, one isolated half at a time.

Because the SZRKBD and original board share their normal USB VID:PID and the RP2040 BOOTSEL loader is generic, a browser cannot reliably infer which physical PCB is attached before Corne Control firmware runs. Initial flashing therefore requires an explicit model choice. After boot, WebHID reads the distinct protocol board ID.
