// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (C) 2026 Qwuille

#pragma once

#include <stdint.h>

#define CORNE_CONTROL_COMMAND 0x72
#define CORNE_CONTROL_PROTOCOL_MAJOR 1
#define CORNE_CONTROL_PROTOCOL_MINOR 1

enum corne_control_board_id {
    CORNE_BOARD_XTIPS_V4S_103C = 1,
    CORNE_BOARD_SZRKBD_CORNE_V41 = 2,
    CORNE_BOARD_FOOSTAN_CORNE_V41 = 3,
};

enum corne_control_operation {
    CORNE_OP_GET_INFO = 0x00,
    CORNE_OP_GET_LIGHTING = 0x01,
    CORNE_OP_SET_LIGHTING = 0x02,
    CORNE_OP_GET_STATUS = 0x03,
    CORNE_OP_HEARTBEAT = 0x04,
    CORNE_OP_PREVIEW_LIGHTING = 0x05,
};

enum corne_control_status {
    CORNE_STATUS_OK = 0,
    CORNE_STATUS_BAD_LENGTH = 1,
    CORNE_STATUS_BAD_OPERATION = 2,
    CORNE_STATUS_BAD_VALUE = 3,
};

enum corne_control_owner {
    CORNE_OWNER_FIRMWARE = 0,
    CORNE_OWNER_OPENRGB = 1,
};

enum corne_control_effect {
    CORNE_EFFECT_SOLID = 0,
    CORNE_EFFECT_BREATHING = 1,
    CORNE_EFFECT_RAINBOW = 2,
    CORNE_EFFECT_HUE_WAVE = 3,
    CORNE_EFFECT_REACTIVE = 4,
    CORNE_EFFECT_COUNT,
};
