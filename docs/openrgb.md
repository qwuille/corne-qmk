# OpenRGB setup

All targets expose VialRGB on the same Raw HID interface used by Vial. No bridge process or second HID interface is required.

## One-time registration

Use an OpenRGB version containing the QMK VialRGB controller. Under **Settings → QMK VialRGB Devices**, add the applicable device and rescan:

| Board name | VID | PID | LEDs |
| --- | --- | --- | --- |
| XTIPS V4s 103C | `5262` | `4E4B` | 2 |
| SZRKBD Corne v4.1 | `4653` | `0004` | 46 |
| foostan Corne v4.1 standard | `4653` | `0004` | 46 |

These are hexadecimal values. The XTIPS pixels are reported at the physical F and J key positions. Both RP2040 targets report foostan's 46-pixel v4.1 standard layout and share the upstream USB VID:PID; their firmware protocol board IDs remain distinct.

## Grant lighting ownership

1. Open the Corne Control WebHID page.
2. Connect the keyboard.
3. Select **OpenRGB** as lighting owner.
4. Close or disconnect the WebHID page.
5. Wait five seconds, then rescan or select the device in OpenRGB.

WebHID keeps configuration priority while connected. Vial keymap commands remain usable, but closing OpenRGB before making large Vial changes is the conservative workflow because both applications share one Raw HID endpoint.

Return ownership to **Keyboard firmware** to reject streamed lighting and restore the last persistent QMK RGB Matrix effect.

## Sleep and shutdown

Normal USB suspend and loss of configured USB state both blank the LEDs. This includes the case where motherboard standby power remains present after host shutdown. On wake, firmware state becomes active again; OpenRGB can replace it with a fresh direct frame when it reconnects.

Physical acceptance tests are still required on each board:

1. Stream distinct colors to every LED.
2. Verify the secondary half receives its pixels with USB connected to the left.
3. Repeat with USB connected to the right.
4. Test sleep, wake, shutdown with USB standby power, and cold boot.
5. Confirm no LED remains latched after the host is no longer configured.
