// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (C) 2026 Qwuille

#include QMK_KEYBOARD_H

#include <string.h>

#include "corne_control.h"
#include "eeconfig.h"
#include "host.h"
#include "raw_hid.h"
#include "rgb_matrix.h"
#include "split_util.h"
#include "timer.h"
#include "transactions.h"
#include "usb_device_state.h"
#include "via.h"

#ifndef CORNE_CONTROL_BOARD_ID
#    error CORNE_CONTROL_BOARD_ID must identify the keyboard target
#endif
#ifndef CORNE_CONTROL_LED_COUNT
#    define CORNE_CONTROL_LED_COUNT RGB_MATRIX_LED_COUNT
#endif
#ifndef CORNE_CONTROL_LEFT_LED_COUNT
#    error CORNE_CONTROL_LEFT_LED_COUNT must identify the split LED boundary
#endif
#ifndef CORNE_CONTROL_DYNAMIC_LAYERS
#    define CORNE_CONTROL_DYNAMIC_LAYERS DYNAMIC_KEYMAP_LAYER_COUNT
#endif
#ifndef CORNE_CONTROL_MAX_BRIGHTNESS
#    define CORNE_CONTROL_MAX_BRIGHTNESS RGB_MATRIX_MAXIMUM_BRIGHTNESS
#endif

#define CORNE_CONFIG_MAGIC 0xC7u
#define CORNE_CONFIG_OWNER_BIT 8u
#define CORNE_CONFIGURATION_HOLD_MS 5000u
#define CORNE_RGB_QUEUE_DEPTH 4u
#define CORNE_RGB_PACKET_MAX_LEDS 9u

typedef struct {
    uint8_t first;
    uint8_t count;
    uint8_t hsv[CORNE_RGB_PACKET_MAX_LEDS * 3];
} corne_rgb_packet_t;

static bool               openrgb_enabled;
static bool               owner_sync_pending;
static uint32_t           configuration_timer;
static corne_rgb_packet_t rgb_queue[CORNE_RGB_QUEUE_DEPTH];
static uint8_t            rgb_queue_read;
static uint8_t            rgb_queue_write;
static uint8_t            rgb_queue_count;

#ifdef RGB_MATRIX_EFFECT_VIALRGB_DIRECT
extern HSV g_direct_mode_colors[RGB_MATRIX_LED_COUNT];
#endif

static uint32_t corne_config_value(void) {
    return CORNE_CONFIG_MAGIC | ((uint32_t)openrgb_enabled << CORNE_CONFIG_OWNER_BIT);
}

static void corne_config_write(void) {
    eeconfig_update_user(corne_config_value());
}

static void corne_set_owner(bool use_openrgb) {
    if (openrgb_enabled == use_openrgb) {
        return;
    }

    openrgb_enabled = use_openrgb;
    corne_config_write();
    owner_sync_pending = true;
    if (!openrgb_enabled) {
        rgb_matrix_reload_from_eeprom();
    }
}

static uint8_t corne_effect_from_qmk(uint8_t mode) {
    switch (mode) {
        case RGB_MATRIX_BREATHING:
            return CORNE_EFFECT_BREATHING;
        case RGB_MATRIX_CYCLE_ALL:
            return CORNE_EFFECT_RAINBOW;
        case RGB_MATRIX_HUE_WAVE:
            return CORNE_EFFECT_HUE_WAVE;
        case RGB_MATRIX_SOLID_REACTIVE_SIMPLE:
            return CORNE_EFFECT_REACTIVE;
        default:
            return CORNE_EFFECT_SOLID;
    }
}

static uint8_t corne_effect_to_qmk(uint8_t effect) {
    switch (effect) {
        case CORNE_EFFECT_BREATHING:
            return RGB_MATRIX_BREATHING;
        case CORNE_EFFECT_RAINBOW:
            return RGB_MATRIX_CYCLE_ALL;
        case CORNE_EFFECT_HUE_WAVE:
            return RGB_MATRIX_HUE_WAVE;
        case CORNE_EFFECT_REACTIVE:
            return RGB_MATRIX_SOLID_REACTIVE_SIMPLE;
        default:
            return RGB_MATRIX_SOLID_COLOR;
    }
}

static void corne_apply_lighting(const uint8_t *data) {
    const bool    enabled = data[4] != 0;
    const uint8_t effect  = data[5];
    const uint8_t hue     = data[6];
    const uint8_t sat     = data[7];
    const uint8_t val     = data[8] > CORNE_CONTROL_MAX_BRIGHTNESS ? CORNE_CONTROL_MAX_BRIGHTNESS : data[8];
    const uint8_t speed   = data[9];

    rgb_matrix_sethsv(hue, sat, val);
    rgb_matrix_set_speed(speed);
    rgb_matrix_mode(corne_effect_to_qmk(effect));
    if (enabled) {
        rgb_matrix_enable();
    } else {
        rgb_matrix_disable();
    }
}

void eeconfig_init_user(void) {
    openrgb_enabled = false;
    corne_config_write();
}

static void corne_rgb_slave_handler(uint8_t in_buflen, const void *in_data, uint8_t out_buflen, void *out_data) {
    (void)out_buflen;
    (void)out_data;
#ifdef RGB_MATRIX_EFFECT_VIALRGB_DIRECT
    if (in_buflen < 2) {
        return;
    }

    const corne_rgb_packet_t *packet = (const corne_rgb_packet_t *)in_data;
    uint8_t count = packet->count > CORNE_RGB_PACKET_MAX_LEDS ? CORNE_RGB_PACKET_MAX_LEDS : packet->count;
    if ((uint8_t)(2 + count * 3) > in_buflen) {
        return;
    }

    for (uint8_t i = 0; i < count; ++i) {
        uint16_t led = packet->first + i;
        if (led >= RGB_MATRIX_LED_COUNT) {
            break;
        }
        g_direct_mode_colors[led].h = packet->hsv[i * 3];
        g_direct_mode_colors[led].s = packet->hsv[i * 3 + 1];
        g_direct_mode_colors[led].v = packet->hsv[i * 3 + 2];
    }
#else
    (void)in_buflen;
    (void)in_data;
#endif
}

static void corne_owner_slave_handler(uint8_t in_buflen, const void *in_data, uint8_t out_buflen, void *out_data) {
    (void)out_buflen;
    (void)out_data;
    if (in_buflen != 1) {
        return;
    }

    bool owner = (*(const uint8_t *)in_data) != 0;
    if (openrgb_enabled != owner) {
        openrgb_enabled = owner;
        corne_config_write();
    }
}

void keyboard_post_init_user(void) {
    uint32_t stored = eeconfig_read_user();
    if ((stored & 0xFFu) != CORNE_CONFIG_MAGIC) {
        eeconfig_init_user();
    } else {
        openrgb_enabled = ((stored >> CORNE_CONFIG_OWNER_BIT) & 1u) != 0;
    }
    transaction_register_rpc(CORNE_RGB_SYNC, corne_rgb_slave_handler);
    transaction_register_rpc(CORNE_OWNER_SYNC, corne_owner_slave_handler);
    owner_sync_pending = true;
}

bool vialrgb_allow_write_kb(uint8_t command) {
    (void)command;
    return openrgb_enabled && timer_elapsed32(configuration_timer) >= CORNE_CONFIGURATION_HOLD_MS;
}

void vialrgb_direct_update_kb(uint16_t first, uint8_t count) {
#ifdef RGB_MATRIX_EFFECT_VIALRGB_DIRECT
    if (!is_keyboard_master() || count == 0) {
        return;
    }

    const uint16_t remote_start = is_keyboard_left() ? CORNE_CONTROL_LEFT_LED_COUNT : 0;
    const uint16_t remote_end   = is_keyboard_left() ? RGB_MATRIX_LED_COUNT : CORNE_CONTROL_LEFT_LED_COUNT;
    uint16_t       start        = first < remote_start ? remote_start : first;
    uint16_t       end          = first + count;
    if (end > remote_end) {
        end = remote_end;
    }
    count = end > start ? end - start : 0;
    if (count == 0) {
        return;
    }
    if (count > CORNE_RGB_PACKET_MAX_LEDS) {
        count = CORNE_RGB_PACKET_MAX_LEDS;
    }

    if (rgb_queue_count == CORNE_RGB_QUEUE_DEPTH) {
        rgb_queue_read = (rgb_queue_read + 1) % CORNE_RGB_QUEUE_DEPTH;
        --rgb_queue_count;
    }

    corne_rgb_packet_t *packet = &rgb_queue[rgb_queue_write];
    packet->first = start;
    packet->count = count;
    for (uint8_t i = 0; i < count; ++i) {
        HSV color = g_direct_mode_colors[start + i];
        packet->hsv[i * 3]     = color.h;
        packet->hsv[i * 3 + 1] = color.s;
        packet->hsv[i * 3 + 2] = color.v;
    }
    rgb_queue_write = (rgb_queue_write + 1) % CORNE_RGB_QUEUE_DEPTH;
    ++rgb_queue_count;
#else
    (void)first;
    (void)count;
#endif
}

void housekeeping_task_user(void) {
    if (!is_keyboard_master()) {
        return;
    }

    if (owner_sync_pending) {
        uint8_t owner = openrgb_enabled;
        if (transaction_rpc_send(CORNE_OWNER_SYNC, sizeof(owner), &owner)) {
            owner_sync_pending = false;
        }
        return;
    }

    if (rgb_queue_count == 0) {
        return;
    }

    corne_rgb_packet_t *packet = &rgb_queue[rgb_queue_read];
    uint8_t length = 2 + packet->count * 3;
    if (transaction_rpc_send(CORNE_RGB_SYNC, length, packet)) {
        rgb_queue_read = (rgb_queue_read + 1) % CORNE_RGB_QUEUE_DEPTH;
        --rgb_queue_count;
    }
}

void suspend_power_down_user(void) {
    rgb_matrix_set_suspend_state(true);
}

void suspend_wakeup_init_user(void) {
    rgb_matrix_set_suspend_state(false);
}

void notify_usb_device_state_change_user(struct usb_device_state usb_state) {
    rgb_matrix_set_suspend_state(usb_state.configure_state != USB_DEVICE_STATE_CONFIGURED);
}

static void corne_reply_info(uint8_t *data) {
    data[3]  = CORNE_CONTROL_PROTOCOL_MAJOR;
    data[4]  = CORNE_CONTROL_PROTOCOL_MINOR;
    data[5]  = CORNE_CONTROL_BOARD_ID;
    data[6]  = 0x1F; // RGB Matrix, OpenRGB, split sync, tap dance, host status.
    data[7]  = CORNE_CONTROL_LED_COUNT & 0xFF;
    data[8]  = CORNE_CONTROL_LED_COUNT >> 8;
    data[9]  = CORNE_CONTROL_LEFT_LED_COUNT;
    data[10] = CORNE_CONTROL_MAX_BRIGHTNESS;
    data[11] = CORNE_CONTROL_DYNAMIC_LAYERS;
    data[12] = CORNE_EFFECT_COUNT;
}

static void corne_reply_lighting(uint8_t *data) {
    data[3]  = openrgb_enabled ? CORNE_OWNER_OPENRGB : CORNE_OWNER_FIRMWARE;
    data[4]  = rgb_matrix_is_enabled();
    data[5]  = corne_effect_from_qmk(rgb_matrix_get_mode());
    data[6]  = rgb_matrix_get_hue();
    data[7]  = rgb_matrix_get_sat();
    data[8]  = rgb_matrix_get_val();
    data[9]  = rgb_matrix_get_speed();
    data[10] = rgb_matrix_get_suspend_state();
}

static void corne_reply_status(uint8_t *data) {
    led_t leds = host_keyboard_led_state();
    data[3] = get_highest_layer(layer_state | default_layer_state);
    data[4] = leds.raw;
    data[5] = is_keyboard_master();
    data[6] = rgb_matrix_get_suspend_state();
}

void raw_hid_receive_kb(uint8_t *data, uint8_t length) {
    if (data[0] != CORNE_CONTROL_COMMAND) {
        data[0] = id_unhandled;
        return;
    }

    if (length != 32) {
        data[2] = CORNE_STATUS_BAD_LENGTH;
        return;
    }

    const uint8_t operation = data[1];
    data[2] = CORNE_STATUS_OK;
    configuration_timer = timer_read32();

    switch (operation) {
        case CORNE_OP_GET_INFO:
            memset(&data[3], 0, 29);
            corne_reply_info(data);
            break;
        case CORNE_OP_GET_LIGHTING:
            memset(&data[3], 0, 29);
            corne_reply_lighting(data);
            break;
        case CORNE_OP_SET_LIGHTING:
            if (data[3] > CORNE_OWNER_OPENRGB || data[4] > 1 || data[5] >= CORNE_EFFECT_COUNT) {
                data[2] = CORNE_STATUS_BAD_VALUE;
                break;
            }
            corne_set_owner(data[3] == CORNE_OWNER_OPENRGB);
            if (!openrgb_enabled) {
                corne_apply_lighting(data);
            }
            break;
        case CORNE_OP_GET_STATUS:
            memset(&data[3], 0, 29);
            corne_reply_status(data);
            break;
        case CORNE_OP_HEARTBEAT:
            break;
        default:
            data[2] = CORNE_STATUS_BAD_OPERATION;
            break;
    }
}
