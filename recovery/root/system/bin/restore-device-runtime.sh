#!/system/bin/sh
# Restore only RAM copies after source partitions have been released.
cache=/tmp/device-runtime
for base in vendor odm; do
    source="$cache/$base/firmware"
    [ -d "$source" ] || continue
    # Never write through a still-mounted ROM partition (including read-write).
    if grep -q " /$base " /proc/mounts; then
        echo "device-runtime: /$base still mounted; skipping restore" >> /tmp/recovery.log
        exit 1
    fi
    # AOSP ramdisks map /odm/firmware into /vendor/odm. Restore a separate
    # directory so odm resources cannot overwrite the vendor copy.
    [ ! -L "/$base/firmware" ] || rm "/$base/firmware" || exit 1
    mkdir -p "/$base/firmware" || exit 1
    cp -R "$source/." "/$base/firmware/" || exit 1
done
setprop twrp.device.runtime.ready true
exit 0
