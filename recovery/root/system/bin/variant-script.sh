#!/system/bin/sh

# init execs this from init.recovery.qcom.rc before the recovery service starts.
# It names the running device, sets the version suffix that TWRP reads once at
# startup, and installs the ZIP64-safe unzip front-end.
#
# One image serves the whole family, so the identity comes from the hardware
# rather than the build. ro.boot.hardware.sku is the codename the bootloader
# reports; marble additionally sells under two names by region, which is what
# ro.boot.hwc distinguishes. Adding a device means one more case below.

# Installers check the device name, not the model. AnyKernel3 tests
# ro.product.device, ro.build.product, ro.product.vendor.device and
# ro.vendor.product.device against its own list and aborts with "Unsupported
# device" otherwise, and TWRP checks the same first property against an OTA
# package's pre-device. The build leaves all of them saying "taro", which is the
# product name shared by nine devices, so every device-specific zip refused to
# install.
DEVICE_NAME_PROPS="ro.product.device ro.build.product ro.product.vendor.device
                   ro.vendor.product.device ro.product.odm.device
                   ro.product.system.device ro.product.system_ext.device
                   ro.product.product.device ro.product.bootimage.device"

# Setting the live properties is only half of it. A flashable zip's own setup
# mounts the installed system over /system, which shadows recovery's toolbox and
# leaves getprop unusable; AnyKernel3 then falls back to reading default.prop and
# build.prop off disk, where this image still names the product. /default.prop
# links to prop.default and is the first file that fallback opens, and its reader
# takes the last match for a key, so the file has to agree with the properties.
line_count() {
    n="$(wc -l < "$1" 2>/dev/null)"
    case "${n}" in
        ''|*[!0-9]*) echo 0 ;;
        *)           echo "${n}" ;;
    esac
}

set_device_name_on_disk() {
    if [ ! -w /prop.default ]; then
        echo "E:identity: /prop.default is not writable, zips still read the product name" >> "${LOGF}"
        return 0
    fi

    original="$(line_count /prop.default)"
    [ "${original}" -gt 0 ] || return 0

    new=/tmp/prop.default.new
    rm -f "${new}"
    grep -vE "^(ro\.product\.device|ro\.build\.product|ro\.product\.vendor\.device|ro\.vendor\.product\.device)=" \
        /prop.default > "${new}" 2>/dev/null

    for prop in ro.product.device ro.build.product \
                ro.product.vendor.device ro.vendor.product.device; do
        echo "${prop}=$1" >> "${new}"
    done

    # Two lines out, four in, so the rewrite can only grow. Anything else means a
    # step failed, and a truncated prop.default is far worse than a device name
    # the installers cannot read.
    if [ "$(line_count "${new}")" -lt "${original}" ]; then
        echo "E:identity: refusing to shrink /prop.default" >> "${LOGF}"
        rm -f "${new}"
        return 0
    fi

    cat "${new}" > /prop.default
    rm -f "${new}"
    echo "I:identity: on-disk device name -> $1" >> "${LOGF}"
}

set_device_name() {
    for prop in ${DEVICE_NAME_PROPS}; do
        resetprop "${prop}" "$1"
    done
    echo "I:identity: device name -> $1" >> "${LOGF}"
    set_device_name_on_disk "$1"
}

set_identity() {
    resetprop "ro.product.brand" "$1"
    resetprop "ro.product.model" "$2"
    # TWRP appends this to its version string: 3.7.1_16-<model>-by-qiqi.
    resetprop "ro.twrp.device_version" "$(echo "$2" | tr ' ' '_')-by-qiqi"
    echo "I:identity: ${sku:-unknown sku} -> $1 $2" >> "${LOGF}"
}

# Route >4 GiB archives away from ziptool, which cannot extract past an
# archive's 4 GiB mark and makes a HyperOS flash a silent no-op. See
# unzip-zip64.
install_zip64_unzip() {
    if [ ! -x /system/bin/unzip-zip64 ] || [ ! -x /system/bin/7za ] ||
            [ ! -x /system/bin/ziptool ]; then
        echo "E:unzip-zip64: prerequisites missing, keeping stock unzip" >> "${LOGF}"
        return 0
    fi

    # ziptool picks its personality from argv[0], so the stock behaviour stays
    # reachable only through a link that is still named "unzip".
    if [ ! -e /system/bin/.ziptool/unzip ]; then
        if ! mkdir -p /system/bin/.ziptool ||
                ! ln -s /system/bin/ziptool /system/bin/.ziptool/unzip; then
            echo "E:unzip-zip64: cannot stage ziptool, keeping stock unzip" >> "${LOGF}"
            return 0
        fi
    fi

    if ln -sf /system/bin/unzip-zip64 /system/bin/unzip; then
        echo "I:unzip-zip64: >4GiB archives now go through 7za" >> "${LOGF}"
    else
        echo "E:unzip-zip64: failed to redirect /system/bin/unzip" >> "${LOGF}"
    fi
}

LOGF=/tmp/recovery.log
sku="$(getprop ro.boot.hardware.sku)"
region="$(getprop ro.boot.hwc)"

echo "I:identity: sku='${sku}' region='${region}'" >> "${LOGF}"

[ -n "${sku}" ] && set_device_name "${sku}"

case "${sku}" in
    marble)
        if [ "${region}" = "CN" ]; then
            set_identity "Redmi" "Redmi Note 12 Turbo"
        else
            set_identity "POCO" "POCO F5"
        fi
        ;;
    mayfly)
        set_identity "Xiaomi" "Xiaomi 12S"
        ;;
    mondrian)
        if [ "${region}" = "CN" ]; then
            set_identity "Redmi" "Redmi K60"
        else
            set_identity "POCO" "POCO F5 Pro"
        fi
        ;;
    diting)
        if [ "${region}" = "CN" ]; then
            set_identity "Redmi" "Redmi K50 Ultra"
        else
            set_identity "Xiaomi" "Xiaomi 12T Pro"
        fi
        ;;
    unicorn)
        set_identity "Xiaomi" "Xiaomi 12S Pro"
        ;;
    thor)
        set_identity "Xiaomi" "Xiaomi 12S Ultra"
        ;;
    cupid)
        set_identity "Xiaomi" "Xiaomi 12"
        ;;
    zeus)
        set_identity "Xiaomi" "Xiaomi 12 Pro"
        ;;
    ingres)
        if [ "${region}" = "CN" ]; then
            set_identity "Redmi" "Redmi K50 Gaming"
        else
            set_identity "POCO" "POCO F4 GT"
        fi
        ;;
    *)
        # An unlisted taro device still deserves its own name rather than the
        # product name every member of the family shares.
        if [ -n "${sku}" ]; then
            set_identity "Xiaomi" "${sku}"
            echo "W:identity: no entry for sku '${sku}', using the codename" >> "${LOGF}"
        else
            echo "E:identity: no sku reported, keeping build values" >> "${LOGF}"
        fi
        ;;
esac

install_zip64_unzip

exit 0
