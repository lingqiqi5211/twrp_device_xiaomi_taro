#!/system/bin/sh

# Drop a touch driver that registered but never bound to anything, so TWRP can
# load the vendor_dlkm copy that matches the running kernel. init runs this
# from init.recovery.qcom.rc before the recovery service starts. Ask the module
# whether it holds a device rather than probing one fixed path: the panel is a
# platform device on some members of this family and an SPI device on others,
# and a module can register a driver on both buses.

LOGF=/tmp/recovery.log
# Every touch driver the family ships. The kernel turns a hyphen in a module
# file name into an underscore, so these are the /proc/modules spellings.
TOUCH_MODULES="goodix_core fts_touch_spi focaltech_fts \
               synaptics_dsx nt36xxx_i2c nt36xxx_spi"

module_has_device() {
    for driver in /sys/module/"$1"/drivers/*; do
        [ -d "${driver}" ] || continue
        for entry in "${driver}"/*; do
            [ -e "${entry}" ] || continue
            case "${entry##*/}" in
                bind|unbind|uevent|module|new_id|remove_id) continue ;;
            esac
            return 0
        done
    done
    return 1
}

for module in ${TOUCH_MODULES}; do
    grep -q "^${module} " /proc/modules || continue
    module_has_device "${module}" && continue
    if rmmod "${module}"; then
        echo "I:modules_fix: unloaded unbound ${module}" >> "${LOGF}"
    else
        echo "E:modules_fix: failed to unload unbound ${module}" >> "${LOGF}"
        exit 1
    fi
done

exit 0
