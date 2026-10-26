#!/system/bin/sh
# Only THP devices need the userspace reporting daemon. Keep the regular
# FocalTech/Synaptics/Novatek input paths in this shared image untouched.
attempt=0
while [ "$attempt" -lt 5 ]; do
    if [ -e /sys/class/touch/touch_dev/touch_thp_cmd ] &&
       [ -e /sys/class/touch/touch_dev/touch_thp_cmd_data ] &&
       [ -e /dev/xiaomi-touch ]; then
        case "$(getprop ro.boot.hardware.sku)" in
            unicorn|zeus)
                # The root setup service can prepare the ST daemon permissions.
                /system/bin/sh /system/bin/run-touch-report.sh --prepare || exit 1
                ;;
        esac
        setprop twrp.touch.thp true
        exit 0
    fi
    attempt=$((attempt + 1))
    sleep 1
done
echo "touch_report: no THP interface; skipping" > /dev/kmsg
