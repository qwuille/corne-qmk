// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (C) 2026 Qwuille

#include QMK_KEYBOARD_H

#include "rgb_matrix.h"

// The V4s has one WS2812 under F on the left and one under J on the right.
led_config_t g_led_config = {
    {
        {NO_LED, NO_LED, NO_LED, NO_LED, NO_LED, NO_LED, NO_LED},
        {NO_LED, NO_LED, NO_LED, NO_LED, 0,      NO_LED, NO_LED},
        {NO_LED, NO_LED, NO_LED, NO_LED, NO_LED, NO_LED, NO_LED},
        {NO_LED, NO_LED, NO_LED, NO_LED, NO_LED, NO_LED, NO_LED},
        {NO_LED, NO_LED, NO_LED, NO_LED, NO_LED, NO_LED, NO_LED},
        {NO_LED, NO_LED, NO_LED, 1,      NO_LED, NO_LED, NO_LED},
        {NO_LED, NO_LED, NO_LED, NO_LED, NO_LED, NO_LED, NO_LED},
        {NO_LED, NO_LED, NO_LED, NO_LED, NO_LED, NO_LED, NO_LED},
    },
    {{68, 20}, {156, 20}},
    {LED_FLAG_KEYLIGHT, LED_FLAG_KEYLIGHT},
};
