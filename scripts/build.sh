#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tree_root="$(cd "${script_dir}/.." && pwd)"
twrp_source="${TWRP_SOURCE:-$(pwd)}"
twrp_product="${TWRP_PRODUCT:-twrp_taro}"

case "${twrp_product}" in
    twrp_taro|twrp_taro_wifi)
        ;;
    *)
        echo "Unsupported TWRP product: ${twrp_product}" >&2
        exit 1
        ;;
esac

if [[ ! -f "${twrp_source}/build/envsetup.sh" ]]; then
    echo "TWRP source not found at: ${twrp_source}" >&2
    echo "Run from the TWRP source root or set TWRP_SOURCE." >&2
    exit 1
fi

twrp_source="$(cd "${twrp_source}" && pwd)"
target_tree="${twrp_source}/device/xiaomi/taro"

if [[ "${tree_root}" != "${target_tree}" ]]; then
    command -v rsync >/dev/null || {
        echo "rsync is required to copy the device tree." >&2
        exit 1
    }
    mkdir -p "${target_tree}"
    rsync -a --delete \
        --exclude=.git \
        --exclude=.github \
        --exclude=.codex-cache \
        --exclude=.codex-context \
        "${tree_root}/" "${target_tree}/"
fi

if [[ "${twrp_product}" == "twrp_taro_wifi" ]]; then
    if [[ -z "${OUT_DIR:-}" ]]; then
        export OUT_DIR="out-taro-wifi"
    fi
fi

bash "${target_tree}/scripts/apply-patches.sh" "${twrp_source}" "${twrp_product}"

cd "${twrp_source}"

# Removed prebuilts and relinked libraries can survive in an incremental out
# directory even after their source files change, and so do files left behind by
# a rename. Purge what this tree has dropped or renamed, plus the recovery
# packaging stamps, so the ramdisk is rebuilt from the current device tree and
# TWRP source.
product_out="${OUT_DIR:-out}/target/product/taro"
for stale_file in \
    recovery/root/system/bin/crash_dump32 \
    recovery/root/system/bin/vendor.qti.hardware.vibrator.service \
    recovery/root/system/bin/wpa_cli_recovery \
    recovery/root/system/bin/wpa_supplicant_recovery \
    recovery/root/system/etc/init/vendor.qti.hardware.vibrator.service.rc \
    recovery/root/system/lib64/libminuitwrp.so \
    recovery/root/system/lib64/libusbhost.so \
    recovery/root/system/lib64/libusbhost_twrp.so \
    recovery/root/vendor/etc/vintf/manifest/vendor.qti.hardware.vibrator.service.xml \
    recovery/root/vendor/lib64/hw/android.hardware.health@2.0-impl-2.1-qti.so \
    recovery/root/vendor/lib64/libaachaptics.so \
    recovery/root/vendor/lib64/libqtivibratoreffect.xiaomi.so \
    recovery/root/vendor/lib64/libqtivibratoreffectoffload.so \
    recovery/root/vendor/lib64/vendor.qti.hardware.vibrator.impl.so \
    recovery/root/vendor/lib64/vendor.qti.hardware.vibratorOL.impl.so \
    recovery/root/vendor/lib64/vendor.qti.hardware.vibratorSel.impl.so; do
    rm -f -- "${product_out}/${stale_file}"
done
# Everything this tree installs is named after the platform now. The old
# per-device names survive in an incremental out directory and would ship
# alongside their replacements, so sweep them by prefix rather than listing each.
for stale_dir in \
    system/bin \
    system/etc/init \
    vendor/etc/init \
    vendor/etc/vintf/manifest \
    vendor/etc/wifi; do
    rm -f -- "${product_out}/recovery/root/${stale_dir}"/marble*
done
# Relinking is three separate phony packages, one per destination, and each only
# re-copies its own list when its own timestamp is gone.
for relink_module in relink_libraries relink_binaries relink_vendor_hw_binaries; do
    rm -f -- \
        "${product_out}/obj/FAKE/${relink_module}_intermediates/${relink_module}-timestamp" \
        "${product_out}/recovery/root/${relink_module}-timestamp"
done
rm -f -- \
    "${product_out}/obj/PACKAGING/recovery_intermediates/ramdisk_files-timestamp" \
    "${product_out}/ramdisk-recovery.img" \
    "${product_out}/recovery.img"

# kati does not always notice that this tree's makefiles changed, and then the
# recovery binary keeps the cflags baked in from the previous run -- a
# BoardConfig-only edit such as TW_LOAD_VENDOR_MODULES silently never reaches
# the image. Drop its stamps when anything here is newer than what it generated.
kati_ninja="${OUT_DIR:-out}/build-${twrp_product}.ninja"
if [[ -f "${kati_ninja}" ]] &&
        [[ -n "$(find "${target_tree}" -name '*.mk' -newer "${kati_ninja}" -print -quit)" ]]; then
    echo "Device makefiles changed since kati last ran; forcing a regeneration."
    rm -f -- "${OUT_DIR:-out}"/.kati_stamp-* "${OUT_DIR:-out}/last_kati_suffix"
fi

export ALLOW_MISSING_DEPENDENCIES=true

# Blueprint calls debug.SetGCPercent(-1), so soong_build's analysis heap only
# ever grows -- around 20 GiB on this tree, which OOM-kills a smaller machine
# before swap can help. SOONG_GOMEMLIMIT makes the runtime collect as it nears a
# ceiling instead, for a few percent of wall clock. A caller's value wins.
if [[ -z "${SOONG_GOMEMLIMIT:-}" ]] && [[ -r /proc/meminfo ]]; then
    mem_kib="$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)"
    if [[ -n "${mem_kib}" ]] && [[ "${mem_kib}" -gt 0 ]]; then
        export SOONG_GOMEMLIMIT="$((mem_kib * 70 / 100 / 1024))MiB"
        echo "Soong memory ceiling: SOONG_GOMEMLIMIT=${SOONG_GOMEMLIMIT} (70% of MemTotal)"
    fi
fi
# Generated by the selected Android source tree and intentionally external to
# this device-tree repository.
# shellcheck disable=SC1091
set +u
source build/envsetup.sh
lunch "${twrp_product}-bp2a-eng"
# crash_dump only exists inside the com.android.runtime APEX and nothing in the
# recoveryimage graph depends on that staging step, so RECOVERY_BINARY_SOURCE_FILES
# would find nothing to copy on a clean out directory -- and say nothing about it.
# Build the file first, as its own goal.
m "${BUILD_JOBS:--j$(nproc)}" "${product_out}/apex/com.android.runtime/bin/crash_dump64"
m "${BUILD_JOBS:--j$(nproc)}" recoveryimage
set -u

image="${OUT_DIR:-${twrp_source}/out}/target/product/taro/recovery.img"
[[ -s "${image}" ]] || {
    echo "Build completed without a recovery image: ${image}" >&2
    exit 1
}

echo "Built: ${image}"
sha256sum "${image}"
