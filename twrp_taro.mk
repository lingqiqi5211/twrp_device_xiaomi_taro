# Copyright (C) 2026 The Android Open Source Project
# SPDX-License-Identifier: Apache-2.0

DEVICE_PATH := device/xiaomi/taro

$(call inherit-product, $(DEVICE_PATH)/device.mk)

# One image serves the whole taro family, so the product is named after the
# platform. runatboot.sh replaces the brand and model at startup with whatever
# ro.boot.hardware.sku says the running device is.
PRODUCT_RELEASE_NAME := taro
PRODUCT_DEVICE := taro
PRODUCT_NAME := twrp_taro
PRODUCT_BRAND := Xiaomi
PRODUCT_MODEL := taro
PRODUCT_MANUFACTURER := Xiaomi
