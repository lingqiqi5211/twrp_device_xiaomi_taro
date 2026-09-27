/*
 * Copyright (C) 2021 The Android Open Source Project
 * SPDX-License-Identifier: Apache-2.0
 */

// hardware/interfaces/health/aidl/default/main.cpp without charger mode.

#include <android-base/logging.h>
#include <android/binder_interface_utils.h>
#include <health-impl/Health.h>
#include <health/utils.h>

using aidl::android::hardware::health::HalHealthLoop;
using aidl::android::hardware::health::Health;

int main(int /* argc */, char** argv) {
    android::base::InitLogging(argv, android::base::KernelLogger);

    auto config = std::make_unique<healthd_config>();
    ::android::hardware::health::InitHealthdConfig(config.get());
    auto binder = ndk::SharedRefBase::make<Health>("default", std::move(config));

    LOG(INFO) << "Starting health HAL.";
    return std::make_shared<HalHealthLoop>(binder, binder)->StartLoop();
}
