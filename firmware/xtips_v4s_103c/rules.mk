# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2026 Qwuille

VIA_ENABLE = yes
VIAL_ENABLE = yes
VIALRGB_ENABLE = yes
TAP_DANCE_ENABLE = yes

RGBLIGHT_ENABLE = no
RGB_MATRIX_ENABLE = yes
RGB_MATRIX_DRIVER = ws2812

CONSOLE_ENABLE = no
COMMAND_ENABLE = no
NKRO_ENABLE = no
LTO_ENABLE = yes

SRC += corne_control.c target_rgb.c
