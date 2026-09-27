# Copyright (C) 2026 The Android Open Source Project
# SPDX-License-Identifier: Apache-2.0

$(call inherit-product, $(SRC_TARGET_DIR)/product/base.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit_only.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/emulated_storage.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/virtual_ab_ota/compression_with_xor.mk)
$(call inherit-product, vendor/twrp/config/common.mk)

# The recovery is built from the Android 16/API 36 tree, but the vendor stack it
# loads is far older. Keep the shipping level truthful for that stack.
BOARD_SHIPPING_API_LEVEL := 33
SHIPPING_API_LEVEL := 33
PRODUCT_SHIPPING_API_LEVEL := 33
PRODUCT_TARGET_VNDK_VERSION := 33
PRODUCT_CHECK_PREBUILT_MAX_PAGE_SIZE := false

# A/B and dynamic partitions
AB_OTA_UPDATER := true
AB_OTA_PARTITIONS += \
    boot \
    init_boot \
    vendor_boot \
    recovery \
    vendor_dlkm \
    dtbo \
    vbmeta \
    vbmeta_system \
    super
PRODUCT_USE_DYNAMIC_PARTITIONS := true

# Recovery runtime
PRODUCT_PACKAGES += \
    android.hardware.boot@1.2-service \
    taro_health \
    android.hardware.gatekeeper@1.0 \
    android.hardware.keymaster@4.0 \
    android.hardware.keymaster@4.1 \
    android.hardware.security.keymint-V4-ndk \
    android.hardware.security.rkp-V3-ndk \
    android.hardware.security.secureclock-V1-ndk \
    android.hardware.security.sharedsecret-V1-ndk \
    libkeymaster_messages \
    libkeymaster_portable \
    fastbootd \
    update_engine \
    update_engine_client \
    update_engine_sideload \
    update_verifier

# crash_dump only installs inside the com.android.runtime APEX, and listing it
# in TARGET_RECOVERY_DEVICE_MODULES is not enough: that becomes a required-module
# edge which ALLOW_MISSING_DEPENDENCIES drops without a word, so the recovery
# image was built with no crash_dump at all. Requesting the package directly
# forces the build, and BoardConfig copies the APEX output into the ramdisk.
PRODUCT_PACKAGES += \
    crash_dump

# Filesystem utilities
PRODUCT_PACKAGES += \
    checkpoint_gc \
    check_f2fs \
    f2fs_io \
    sg_write_buffer

PRODUCT_SOONG_NAMESPACES += \
    $(DEVICE_PATH)

PRODUCT_EXTRA_RECOVERY_KEYS += \
    $(DEVICE_PATH)/security/otacert

PRODUCT_SYSTEM_PROPERTIES += \
    persist.sys.fuse.passthrough.enable=true

ifeq ($(TARGET_PRODUCT),twrp_taro_wifi)
$(call inherit-product, $(DEVICE_PATH)/wifi/wifi.mk)
endif
