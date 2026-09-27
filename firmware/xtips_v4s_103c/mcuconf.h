// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (C) 2026 Qwuille

#pragma once

#include_next <mcuconf.h>

// A9 is TIM1 channel 2. Hardware PWM avoids timing jitter on the APM32 clone.
#undef STM32_PWM_USE_TIM1
#define STM32_PWM_USE_TIM1 TRUE
