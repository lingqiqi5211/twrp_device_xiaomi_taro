# Copyright (C) 2026 The Android Open Source Project
# SPDX-License-Identifier: Apache-2.0

DEVICE_PATH := device/xiaomi/taro

# TWRP 16 minimal-manifest compatibility
ALLOW_MISSING_DEPENDENCIES := true
BUILD_BROKEN_DUP_RULES := true
BUILD_BROKEN_ELF_PREBUILT_PRODUCT_COPY_FILES := true
BUILD_BROKEN_NINJA_USES_ENV_VARS += RTIC_MPGEN
BUILD_BROKEN_PLUGIN_VALIDATION := \
    soong-libaosprecovery_defaults \
    soong-libtwrpgui_defaults \
    soong-libtwrpminui_defaults \
    soong-vold_defaults

# Architecture
TARGET_ARCH := arm64
TARGET_ARCH_VARIANT := armv8-a
TARGET_CPU_ABI := arm64-v8a
TARGET_CPU_ABI2 :=
TARGET_CPU_VARIANT := generic

# Platform / bootloader
PRODUCT_PLATFORM := ukee
TARGET_BOARD_PLATFORM := $(PRODUCT_PLATFORM)
TARGET_BOOTLOADER_BOARD_NAME := $(PRODUCT_PLATFORM)
QCOM_BOARD_PLATFORMS += $(PRODUCT_PLATFORM)
TARGET_NO_BOOTLOADER := true
TARGET_USES_REMOTEPROC := true

# Recovery is a ramdisk-only A/B recovery image. The running kernel comes from
# vendor_boot, so the prebuilt is used for build metadata/VINTF validation but
# is not embedded in recovery.img.
BOARD_BOOT_HEADER_VERSION := 4
BOARD_KERNEL_PAGESIZE := 4096
BOARD_MKBOOTIMG_ARGS += --header_version $(BOARD_BOOT_HEADER_VERSION)
BOARD_MKBOOTIMG_ARGS += --pagesize $(BOARD_KERNEL_PAGESIZE)
BOARD_RAMDISK_USE_LZ4 := true
BOARD_EXCLUDE_KERNEL_FROM_RECOVERY_IMAGE := true
TARGET_PREBUILT_KERNEL := $(DEVICE_PATH)/prebuilt/kernel-melt

# Partitions
BOARD_FLASH_BLOCK_SIZE := 262144
BOARD_PROPERTY_OVERRIDES_SPLIT_ENABLED := true
BOARD_RECOVERYIMAGE_PARTITION_SIZE := 104857600
BOARD_SUPER_PARTITION_SIZE := 9663676416
BOARD_SUPER_PARTITION_GROUPS := qti_dynamic_partitions
BOARD_QTI_DYNAMIC_PARTITIONS_SIZE := 9659482112
BOARD_QTI_DYNAMIC_PARTITIONS_PARTITION_LIST := \
    system system_ext product vendor vendor_dlkm odm

TARGET_COPY_OUT_ODM := odm
TARGET_COPY_OUT_VENDOR := vendor
TARGET_COPY_OUT_VENDOR_DLKM := vendor_dlkm
BOARD_ODMIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_VENDOR_DLKMIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_USES_VENDOR_DLKMIMAGE := true

TARGET_USERIMAGES_USE_EXT4 := true
TARGET_USERIMAGES_USE_F2FS := true
TARGET_USES_MKE2FS := true

# Verified Boot
BOARD_AVB_ENABLE := true
BOARD_AVB_RECOVERY_KEY_PATH := external/avb/test/data/testkey_rsa4096.pem
BOARD_AVB_RECOVERY_ALGORITHM := SHA256_RSA4096
BOARD_AVB_RECOVERY_ROLLBACK_INDEX := 1
BOARD_AVB_RECOVERY_ROLLBACK_INDEX_LOCATION := 1

# File-based encryption. This family uses fscrypt v2 with wrapped keys; both the
# legacy HIDL and Android 16+ AIDL QTI security services are shipped below.
BOARD_USES_METADATA_PARTITION := true
TW_INCLUDE_CRYPTO := true
TW_INCLUDE_CRYPTO_FBE := true
TW_INCLUDE_FBE_METADATA_DECRYPT := true
TW_USE_FSCRYPT_POLICY := 2
# The bundled recovery security stack decrypts current userdata without
# system APEX. Runtime loop mounting is broken on this kernel and only adds a
# failed probe before metadata decryption, so keep the recovery ROM-neutral.
TW_EXCLUDE_APEX := true
PLATFORM_VERSION := 99.87.36
PLATFORM_VERSION_LAST_STABLE := $(PLATFORM_VERSION)
PLATFORM_SECURITY_PATCH := 2099-12-31
VENDOR_SECURITY_PATCH := $(PLATFORM_SECURITY_PATCH)
BOOT_SECURITY_PATCH := $(PLATFORM_SECURITY_PATCH)

# Recovery layout. No TARGET_OTA_ASSERT_DEVICE: one image serves every device in
# the family, and the assert would refuse to install on all but one of them.
TARGET_RECOVERY_FSTAB := $(DEVICE_PATH)/recovery.fstab
TARGET_RECOVERY_PIXEL_FORMAT := RGBX_8888
TARGET_RECOVERY_QCOM_RTC_FIX := true
RECOVERY_SDCARD_ON_DATA := true

# Libraries required by the legacy HIDL/QSEE vendor stack. The removed
# QCOM display-interface repositories are intentionally not referenced here.
TARGET_RECOVERY_DEVICE_MODULES += \
    android.hidl.allocator@1.0 \
    android.hidl.memory@1.0 \
    android.hidl.memory.token@1.0 \
    libdmabufheap \
    libexpat \
    libhidlmemory \
    libion \
    libnetutils
RECOVERY_LIBRARY_SOURCE_FILES += \
    $(TARGET_OUT_SHARED_LIBRARIES)/android.hidl.allocator@1.0.so \
    $(TARGET_OUT_SHARED_LIBRARIES)/android.hidl.memory@1.0.so \
    $(TARGET_OUT_SHARED_LIBRARIES)/android.hidl.memory.token@1.0.so \
    $(TARGET_OUT_SHARED_LIBRARIES)/libdmabufheap.so \
    $(TARGET_OUT_SHARED_LIBRARIES)/libexpat.so \
    $(TARGET_OUT_SHARED_LIBRARIES)/libhidlmemory.so \
    $(TARGET_OUT_SHARED_LIBRARIES)/libion.so \
    $(TARGET_OUT_SHARED_LIBRARIES)/libnetutils.so

# lpdumpd links libfs_mgr_binder directly and reaches libsnapshot through
# liblpdump; without either it fails to link and every lpdump call reports
# "Cannot get lpdump service". lptools resolves on its own.
TARGET_RECOVERY_DEVICE_MODULES += \
    libfs_mgr_binder \
    libsnapshot
RECOVERY_LIBRARY_SOURCE_FILES += \
    $(TARGET_OUT_SHARED_LIBRARIES)/libfs_mgr_binder.so \
    $(TARGET_OUT_SHARED_LIBRARIES)/libsnapshot.so

# Display / input
TW_THEME := portrait_hdpi
TW_DEFAULT_LANGUAGE := zh_CN
TW_EXTRA_LANGUAGES := true
# The panel is brought up at 60 Hz by the kernel and TWRP cannot re-initialise
# it for another mode, so pacing the GUI to anything else only drops frames.
TW_FRAMERATE := 60
TW_BRIGHTNESS_PATH := "/sys/class/backlight/panel0-backlight/brightness"
TW_DEFAULT_BRIGHTNESS := 420
TW_MAX_BRIGHTNESS := 4095
TW_NO_SCREEN_BLANK := true

# Device services / modules
TW_EXCLUDE_DEFAULT_USB_INIT := true
# A union across the family: the loader logs "unavailable modules are optional
# for this device" and carries on, so listing another device's touch driver
# costs nothing here.
TW_LOAD_VENDOR_MODULES := "adsp_loader_dlkm.ko goodix_core.ko fts_touch_spi.ko focaltech_fts.ko synaptics_dsx.ko nt36xxx-i2c.ko nt36xxx-spi.ko xiaomi_touch.ko"
TW_LOAD_VENDOR_MODULES_EXCLUDE_GKI := true
TW_USE_SERIALNO_PROPERTY_FOR_DEVICE_ID := true
TW_OVERRIDE_SYSTEM_PROPS := \
    "ro.build.fingerprint=ro.vendor.build.fingerprint;ro.build.version.incremental"

# Tools
TW_ENABLE_ALL_PARTITION_TOOLS := true
TW_INCLUDE_7ZA := true
TW_INCLUDE_FASTBOOTD := true
TW_INCLUDE_LIBRESETPROP := true
TW_INCLUDE_NTFS_3G := true
TW_INCLUDE_REPACKTOOLS := true
TW_INCLUDE_RESETPROP := true
TW_USE_DMCTL := true
TW_USE_TOOLBOX := true

# Logging / build identity
TARGET_USES_LOGD := true
TWRP_INCLUDE_LOGCAT := true
TARGET_RECOVERY_DEVICE_MODULES += debuggerd strace
RECOVERY_BINARY_SOURCE_FILES += \
    $(TARGET_OUT_EXECUTABLES)/debuggerd \
    $(TARGET_OUT_EXECUTABLES)/strace

# None of these declare recovery_available, so build the platform variant and
# copy it in, as debuggerd and strace above do. crash_dump needs
# frameworks/libs/native_bridge_support, which taro-twrp16.xml restores, and
# it now ships inside the com.android.runtime APEX -- nothing mounts APEX here,
# but bionic hardcodes CRASH_DUMP_PATH as /system/bin/crash_dump64, so the APEX
# output is copied there. No crash_dump32: there is no /system/lib to link to.
TARGET_RECOVERY_DEVICE_MODULES += \
    crash_dump \
    libdebuggerd_client \
    libprocinfo
RECOVERY_BINARY_SOURCE_FILES += \
    $(PRODUCT_OUT)/apex/com.android.runtime/bin/crash_dump64
RECOVERY_LIBRARY_SOURCE_FILES += \
    $(TARGET_OUT_SHARED_LIBRARIES)/libdebuggerd_client.so \
    $(TARGET_OUT_SHARED_LIBRARIES)/libprocinfo.so

TW_DEVICE_VERSION := taro-for-lingqiqi
ifeq ($(TARGET_PRODUCT),twrp_taro_wifi)
# Gates the WLAN GUI and network helpers. twrp_taro_wifi.mk installs the two
# supplicant binaries from TWRP's own external/wpa_supplicant_8 fork.
TW_INCLUDE_WIFI := true
TARGET_RECOVERY_DEVICE_MODULES += \
    android.hardware.wifi@1.0 \
    dhcpdbg \
    libnl \
    libssl \
    taro_wifi_halctl
RECOVERY_BINARY_SOURCE_FILES += \
    $(TARGET_OUT_EXECUTABLES)/dhcpdbg \
    $(TARGET_OUT_EXECUTABLES)/taro_wifi_halctl
RECOVERY_LIBRARY_SOURCE_FILES += \
    $(TARGET_OUT_SHARED_LIBRARIES)/android.hardware.wifi@1.0.so \
    $(TARGET_OUT_VENDOR_SHARED_LIBRARIES)/android.hardware.security.keymint-V1-ndk.so \
    $(TARGET_OUT_VENDOR_SHARED_LIBRARIES)/android.system.keystore2-V1-ndk.so \
    $(TARGET_OUT_VENDOR_SHARED_LIBRARIES)/libkeystore-engine-wifi-hidl.so \
    $(TARGET_OUT_SHARED_LIBRARIES)/libnl.so \
    $(TARGET_OUT_SHARED_LIBRARIES)/libssl.so
endif
