#!/system/bin/sh
# Unicorn and Zeus share the ST daemon packaged from Unicorn.
# Other THP devices keep the common daemon.
daemon=/vendor/bin/touch_report
case "$(getprop ro.boot.hardware.sku)" in
    unicorn|zeus) daemon=/vendor/bin/touch_report-unicorn ;;
esac

if [ ! -x "$daemon" ]; then
    echo "touch_report: selected daemon is missing: $daemon" > /dev/kmsg
    exit 1
fi

if [ "$1" = --prepare ]; then
    if [ "$daemon" = /vendor/bin/touch_report-unicorn ]; then
        touch=/sys/class/touch/touch_dev
        # Run in the setup service after module loading. The reporting service
        # has no DAC bypass, and its workers also open touch_thp_dump O_RDWR.
        for node in \
            "$touch/touch_thp_rx_num" "$touch/touch_thp_tx_num" \
            "$touch/touch_thp_x_resolution" "$touch/touch_thp_y_resolution" \
            "$touch/update_rawdata" /dev/xiaomi-touch \
            "$touch/enable_touch_delta" "$touch/suspend_state" \
            "$touch/palm_sensor_data" "$touch/touch_thp_mem_notify" \
            "$touch/touch_thp_dump"; do
            if [ ! -e "$node" ]; then
                echo "touch_report: interface missing: $node" > /dev/kmsg
                exit 1
            fi
            if ! chown 0:0 "$node" || ! chmod 0664 "$node"; then
                echo "touch_report: cannot set owner/access mode: $node" > /dev/kmsg
                exit 1
            fi
        done
        echo "touch_report: permissions ready for $daemon" > /dev/kmsg
    fi
    exit 0
fi

echo "touch_report: starting $daemon" > /dev/kmsg
exec "$daemon"
