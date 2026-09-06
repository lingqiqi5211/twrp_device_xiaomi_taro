# Copyright (C) 2026 The Android Open Source Project
# SPDX-License-Identifier: Apache-2.0

# Keep the proven recovery product unchanged. This product only adds the
# experimental HIDL Wi-Fi runtime and uses a separate build output.
$(call inherit-product, device/xiaomi/taro/twrp_taro.mk)

PRODUCT_NAME := twrp_taro_wifi
PRODUCT_MODEL := taro (Wi-Fi experimental)

# Nothing upstream installs the recovery supplicant any more. It links
# keystore2-V1 through wpa_supplicant_defaults, and anything in
# TARGET_RECOVERY_DEVICE_MODULES becomes a dependency of the recovery module,
# which links V5, so the two binaries install from here.
PRODUCT_PACKAGES += \
    wpa_supplicant_recovery \
    wpa_cli_recovery
