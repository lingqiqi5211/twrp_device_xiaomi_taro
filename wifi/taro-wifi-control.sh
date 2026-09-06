#!/system/bin/sh

set -eu

log_tag="taro_wifi"
iface="wlan0"
ctrl_socket="/tmp/recovery/sockets/${iface}"
cnss_ready_marker="/tmp/taro-wifi-cnss-fs-ready"

log_message() {
    /system/bin/log -t "${log_tag}" "$*"
    echo "$*"
}

is_mounted() {
    /system/bin/grep -q " $1 " /proc/mounts
}

mount_vendor_dlkm() {
    is_mounted /vendor_dlkm && return 0
    slot_suffix="$(/system/bin/getprop ro.boot.slot_suffix)"
    for device in "/dev/block/mapper/vendor_dlkm${slot_suffix}" \
                  /dev/block/mapper/vendor_dlkm; do
        [ -e "${device}" ] || continue
        /system/bin/mkdir -p /vendor_dlkm
        /system/bin/mount -o ro "${device}" /vendor_dlkm 2>/dev/null && return 0
    done
    return 1
}

# insmod is the only reliable judge of whether a module fits the running kernel:
# a custom kernel commonly keeps the stock vermagic so the stock vendor modules
# still load, while uname -r reports its own name, and comparing the two rejects
# modules the kernel would have accepted. Try every candidate and keep the first
# that loads, starting with /lib/modules, which comes from the running boot image
# and so fits by construction.
insmod_first() {
    file_pattern="$1"
    mount_vendor_dlkm || true
    for directory in /lib/modules /vendor_dlkm/lib/modules /vendor/lib/modules \
                     /vendor_dlkm/lib/modules/* /vendor/lib/modules/*; do
        for candidate in "${directory}"/${file_pattern}; do
            [ -f "${candidate}" ] || continue
            if /system/bin/insmod "${candidate}"; then
                log_message "loaded ${candidate}"
                return 0
            fi
        done
    done

    log_message "no usable ${file_pattern} for kernel $(/system/bin/uname -r)"
    return 1
}

load_module() {
    module_name="$1"
    file_name="$2"
    if /system/bin/grep -q "^${module_name} " /proc/modules; then
        return 0
    fi
    insmod_first "${file_name}"
}

signal_cnss_fs_ready() {
    if [ -w /sys/kernel/cnss/fs_ready ] && [ ! -e "${cnss_ready_marker}" ]; then
        echo 1 > /sys/kernel/cnss/fs_ready
        : > "${cnss_ready_marker}"
    fi
}

configure_ping_sockets() {
    if [ -w /proc/sys/net/ipv4/ping_group_range ]; then
        echo "0 2147483647" > /proc/sys/net/ipv4/ping_group_range
    fi
}

clear_network_state() {
    for property in ipaddress gateway dns1 dns2; do
        /system/bin/setprop "net.${iface}.${property}" ""
    done
    : > /etc/resolv.conf
    /system/bin/chmod 0644 /etc/resolv.conf
}

wait_for_iface() {
    attempt=0
    while [ ! -e "/sys/class/net/${iface}" ] && [ "${attempt}" -lt "$1" ]; do
        attempt=$((attempt + 1))
        /system/bin/sleep 0.1
    done
}

start_wifi() {
    slot_suffix="$(/system/bin/getprop ro.boot.slot_suffix)"
    if ! is_mounted /firmware; then
        /system/bin/mkdir -p /firmware
        /system/bin/mount -t vfat -o ro \
            "/dev/block/bootdevice/by-name/modem${slot_suffix}" /firmware
    fi

    if is_mounted /persist && ! is_mounted /mnt/vendor/persist; then
        /system/bin/mkdir -p /mnt/vendor/persist
        /system/bin/mount --bind /persist /mnt/vendor/persist
        /system/bin/mount -o remount,bind,ro /mnt/vendor/persist || true
    fi

    signal_cnss_fs_ready

    # A kernel can carry the whole WLAN stack built in rather than as modules,
    # and then no module name shows up in /proc/modules even though the driver
    # is there. The interface is the thing that matters, so ask for it.
    if [ ! -e "/sys/class/net/${iface}" ]; then
        # cfg80211 can be built into the kernel, in which case there is no file
        # to load and nothing is wrong. The WLAN driver is one module per chip
        # and a taro device carries several, so try them all rather than naming
        # one here. Either way the interface is what decides.
        load_module cfg80211 cfg80211.ko || true
        insmod_first 'qca_cld3_*.ko' || true
        # The qca6490 driver creates the interface only after userspace writes ON
        # to /dev/wlan, as the vendor HAL does at boot. The write returns once the
        # driver is up. The first load after boot also calibrates the firmware,
        # which took about six seconds on marble, so wait well past that.
        attempt=0
        while [ ! -c /dev/wlan ] && [ "${attempt}" -lt 50 ]; do
            attempt=$((attempt + 1))
            /system/bin/sleep 0.1
        done
        if [ ! -e "/sys/class/net/${iface}" ] && [ -c /dev/wlan ]; then
            echo ON > /dev/wlan 2>/dev/null || true
        fi
        wait_for_iface 150
        [ -e "/sys/class/net/${iface}" ] || log_message "no WLAN driver produced ${iface}, trying the HAL"
    fi

    /system/bin/setprop wifi.interface "${iface}"
    if [ "$(/system/bin/getprop init.svc.vendor.wifi_hal_legacy)" != "running" ]; then
        /system/bin/start vendor.wifi_hal_legacy
        attempt=0
        while [ "$(/system/bin/getprop init.svc.vendor.wifi_hal_legacy)" != "running" ]; do
            attempt=$((attempt + 1))
            if [ "${attempt}" -ge 50 ]; then
                log_message "Wi-Fi HAL service did not start"
                return 1
            fi
            /system/bin/sleep 0.1
        done
    fi

    if [ ! -e "/sys/class/net/${iface}" ]; then
        iface_name="$(/system/bin/taro_wifi_halctl start)" || return 1
        if [ "${iface_name}" != "${iface}" ]; then
            log_message "Wi-Fi HAL created unexpected interface: ${iface_name}"
            return 1
        fi
    fi
    /system/bin/ifconfig "${iface}" up
    configure_ping_sockets

    /system/bin/mkdir -p /tmp/recovery/sockets
    /system/bin/chown wifi:wifi /tmp/recovery/sockets
    /system/bin/chmod 0770 /tmp/recovery/sockets

    # TWRP's wpa_cli drops to the wifi user and puts its client socket straight
    # in /tmp, which the ramdisk leaves root:shell 0775. Sticky bit kept so one
    # user cannot remove another's socket.
    /system/bin/chmod 1777 /tmp
    if [ "$(/system/bin/getprop init.svc.wpa_supplicant_recovery)" != "running" ]; then
        /system/bin/rm -f "${ctrl_socket}"
        /system/bin/start wpa_supplicant_recovery
        attempt=0
        while [ ! -S "${ctrl_socket}" ]; do
            attempt=$((attempt + 1))
            if [ "${attempt}" -ge 100 ]; then
                log_message "wpa_supplicant control socket did not appear"
                return 1
            fi
            /system/bin/sleep 0.1
        done
    fi

    log_message "Wi-Fi runtime ready on ${iface}"
}

stop_wifi() {
    /system/bin/stop wpa_supplicant_recovery || true
    if [ -e "/sys/class/net/${iface}" ]; then
        /system/bin/ifconfig "${iface}" down || true
    fi
    clear_network_state
    /system/bin/rm -f "${ctrl_socket}"
    log_message "Wi-Fi stopped and network state cleared; HAL and kernel modules retained"
}

case "${1:-}" in
    start)
        start_wifi
        ;;
    stop)
        stop_wifi
        ;;
    *)
        echo "usage: taro-wifi-control {start|stop}" >&2
        exit 2
        ;;
esac
