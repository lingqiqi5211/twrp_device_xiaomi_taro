#!/system/bin/sh
cache=/tmp/device-runtime/haptics
[ -f "$cache/kind" ] || exit 0
kind=$(cat "$cache/kind")
case "$1:$kind" in
    feature:xiaomi) binary=feature ;;
    alias:xiaomi) binary=alias ;;
    *) exit 0 ;;
esac
# The launcher isolates mounts before dropping to the system user and
# executing the ROM HAL with its private platform/VNDK linker namespaces.
exec /system/bin/taro_haptics_launcher "$binary"
