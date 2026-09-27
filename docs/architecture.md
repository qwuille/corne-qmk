# Firmware architecture

## Separate hardware targets

All three builds share `firmware/common/corne_control.c`, while retaining board-specific Vial identities and overlays. XTIPS has a separate hardware definition and bootloader; the SZRKBD and original foostan builds intentionally share foostan's v4.1 standard hardware definition but report different Corne Control identities.

```text
firmware/
  common/                 shared WebHID, ownership, suspend, split RGB
  xtips_v4s_103c/         APM32F103 target overlay and two-pixel map
  szrkbd_corne_v4_1/      RP2040/foostan v4.1 target overlay
  foostan_corne_v4_1/     original foostan Vial identity and overlay
patches/
  vialrgb-policy-and-split-sync.patch
  vial-tap-dance-reliable-interrupt.patch
webhid/
  index.html              settings and integrated firmware flasher
  flasher.html            compatibility redirect to index.html#firmware
  firmware/               packaged, hash-verified release artifacts
  PROTOCOL.md
```

`tools/build.ps1` stages each overlay into its pinned upstream checkout under ignored `.build/vendor/`. The X-Tips repository supplies the `v4s/103c` hardware target. The foostan wrapper supplies `crkbd/rev4_1/standard` and its pinned Vial-QMK revision.

## Tap Dance

All targets compile QMK Tap Dance, which enables Vial's dynamic Tap Dance implementation. XTIPS allocates eight entries to protect its flash and emulated-EEPROM budget; both RP2040 builds allocate sixteen.

All targets use a 10 ms synthetic tap delay. This prevents the host from missing or reordering the very short press/release report that Vial generates when a Tap Dance ends on release or is interrupted by the next key.

Corne Control also enables **Reliable typing interrupt** by default. Stock Vial may leave the generated single-tap key down until the physical Tap Dance key is released when another key interrupts it. During rolled typing, the following key can consequently be combined with or overtake that report. The maintained Vial patch completes the generated tap before processing the interrupting key. Reliable mode also enforces the firmware's 10 ms minimum Tap Code Delay for Vial Tap Dance reports: an older persisted Vial value of 0 ms can otherwise collapse a synthetic press and release into an intermittently missing key. WebHID can persistently enable or disable this workaround, and the selected value is synchronized to the secondary half. This is related to the upstream Vial report [tap dance triggers press/release in wrong order](https://github.com/vial-kb/vial-qmk/issues/1023). Its status and the requirements for returning to unpatched upstream Vial are recorded in [upstream compatibility tracking](upstream-tracking.md).

Acceptance testing must include tap, hold, double-tap, tap-hold, and interruption by another key. In the interruption case, QMK must finish the pending dance before processing the interrupting key so any layer change affects the new key correctly.

## Lighting ownership

XTIPS drives its A9 WS2812 line from STM32 TIM1 channel 2 with PWM and DMA.
Software bit-banging was rejected after physical testing showed visible flicker
on the APM32F103 clone. Mouse Keys are disabled on XTIPS to make room for solid,
breathing, rainbow, hue-wave, and key-reactive firmware effects;
VialRGB/OpenRGB direct color remains available.

The firmware stores one owner bit in QMK's user EEPROM:

- **Firmware** rejects VialRGB writes and runs the saved QMK RGB Matrix effect.
- **OpenRGB** accepts VialRGB mode and direct-color writes.

Reads remain available in both modes. This avoids two controllers continually overwriting the same LEDs while keeping Vial keymap commands available.

The small Vial core patch adds two generic weak hooks:

- a policy hook before VialRGB writes and saves;
- a notification after each direct-color packet.

## Split direct-color forwarding

Only the USB master receives Raw HID. QMK normally synchronizes RGB Matrix configuration between halves, but VialRGB direct pixel buffers are not configuration data. Corne Control therefore queues the part of every direct packet belonging to the secondary half and sends it through a user split transaction.

The remote range is selected at runtime from physical handedness:

- left master forwards right-half indices;
- right master forwards left-half indices.

Each packet carries at most nine HSV pixels and fits QMK's default 32-byte RPC buffer. Transactions run from the housekeeping task, as recommended by QMK, rather than blocking the Raw HID callback.

A second transaction mirrors the persistent Firmware/OpenRGB owner from the active USB master into the secondary controller. Moving the computer cable to the other half therefore retains the most recently configured ownership state.

## Suspend and shutdown

`RGB_MATRIX_SLEEP` covers normal USB suspend. Some PCs retain USB standby power during shutdown without completing the ordinary suspend path, which can leave the final OpenRGB frame latched. The shared module also observes QMK's USB device state and sets RGB Matrix suspended whenever the device is not configured. Built-in RGB split synchronization carries this state to the other half.

## WebHID

Corne Control command `0x72` is routed through Vial's existing 32-byte vendor HID collection. The versioned protocol provides:

- board identity and capabilities;
- lighting owner and portable effect controls;
- LED count and split boundary;
- active layer, host lock LEDs, master role, and suspend state;
- a configuration heartbeat.

WebHID traffic pauses OpenRGB writes for five seconds. The browser page maintains the heartbeat while connected, so close or disconnect it before using OpenRGB continuously.

The control deck draws both split halves entirely in HTML and CSS. Each key associated with a physical RGB Matrix index receives an animated frame driven by the selected owner, firmware effect, HSV, brightness, and speed. XTIPS therefore frames only F and J; both RP2040 targets frame their 46 LED-equipped keys. This is a configuration preview rather than live readback of OpenRGB's per-pixel buffer, and `prefers-reduced-motion` disables animation.

## Optional external display

The planned USB-C display pod remains separate from this implementation. Because no I2C/UART pads are exposed, a display on the unused connector needs a USB-host-capable MCU, explicit VBUS isolation, and split-role handling. The live-status operation already exposes the minimum layer and lock-state payload that such a pod can reuse later.
