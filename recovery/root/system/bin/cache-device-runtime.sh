#!/system/bin/sh
# Invoked with vendor/odm mounted. All output is optional, boot-scoped RAM data.
cache=/tmp/device-runtime
mkdir -p "$cache" || exit 1
log() { echo "device-runtime: $*" >> /tmp/recovery.log; }
remaining=33554432
copy_file() {
    src=$1; dst=$2
    size=$(stat -Lc %s "$src" 2>/dev/null) || return 1
    case "$size" in ''|*[!0-9]*) return 1 ;; esac
    [ "$size" -gt 0 ] && [ "$size" -le 8388608 ] && [ "$size" -le "$remaining" ] || return 1
    mkdir -p "${dst%/*}" || return 1
    cp -L "$src" "$dst.tmp" && mv "$dst.tmp" "$dst" || return 1
    remaining=$((remaining - size))
}
# Keep vendor and odm paths separate; dereference links while their targets exist.
for base in /vendor /odm; do
    [ -d "$base/firmware" ] || continue
    find "$base/firmware" -maxdepth 3 \( -type f -o -type l \) > "$cache/files" 2>/dev/null
    while IFS= read -r file; do
        case "${file##*/}" in
            goodix*.bin|goodix*.csv|novatek*.bin|synaptics*.bin|synaptics*.img|focaltech*.bin|fts*.bin)
                copy_file "$file" "$cache$file" || log "cannot cache $file" ;;
        esac
    done < "$cache/files"
done
rm -f "$cache/files"
# Isolate optional HAL data from Recovery's crypto and other vendor libraries.
hal="$cache/haptics"
# Readiness is published only after every cache component is complete.
rm -f "$hal/kind"
mkdir -p "$hal/bin" "$hal/lib64" "$hal/platform" || exit 0
vndk_libraries="libbase.so libbinder.so libc++.so libcutils.so libexpat.so
libhardware.so libhidlbase.so libjsoncpp.so libprocessgroup.so libtinyalsa.so
libutils.so libion.so liblzma.so libz.so"
kind=
if [ -f /vendor/bin/hw/vendor.xiaomi.hardware.vibratorfeature.service ] &&
   [ -f /vendor/bin/hw/vendor.vibrator-default-alias ]; then
    copy_file /vendor/bin/hw/vendor.xiaomi.hardware.vibratorfeature.service "$hal/bin/feature" &&
    copy_file /vendor/bin/hw/vendor.vibrator-default-alias "$hal/bin/alias" || exit 0
    kind=xiaomi
else
    # Other vendor services have different private dependencies; do not guess.
    log "no supported Xiaomi AIDL HAL; using fallback"
    exit 0
fi
required_libraries="android.hardware.vibrator-V1-ndk_platform.so
vendor.hardware.vibratorfeature.IVibratorExt-V1-ndk_platform.so
libaachaptics.so
libsoc_helper.so
libmisight.so
libagmclient.so
libagm_mixer_plugin.so
libagmmixer.so
libagmdevice.so
libaudio_log_utils.so
libsndcardparser.so
vendor.qti.hardware.AGMIPC@1.0.so"
vendor_roots="/vendor/lib64"
for root in /system/vendor/lib64 /system_root/system/vendor/lib64; do
    [ -d "$root" ] && vendor_roots="$vendor_roots $root"
done
for library in $required_libraries; do
    found=
    for root in $vendor_roots; do
        if [ -f "$root/$library" ]; then
            found="$root/$library"
            break
        fi
    done
    [ -n "$found" ] || {
        log "missing HAL library $library; using fallback"
        rm -f "$hal/bin/"*
        exit 0
    }
    copy_file "$found" "$hal/lib64/$library" || exit 0
done
# These vendor services use their ROM's VNDK. Never replace Recovery's libraries.
version=$(getprop ro.vendor.vndk.version)
[ -n "$version" ] || version=$(getprop ro.vndk.version)
if [ -z "$version" ]; then
    for properties in /vendor/build.prop /vendor/etc/build.prop; do
        [ -f "$properties" ] || continue
        version=$(sed -n 's/^ro.vndk.version=//p;s/^ro.vendor.vndk.version=//p' "$properties" | head -1)
        [ -z "$version" ] || break
    done
fi
case "$version" in ''|*[!0-9]*) log "no VNDK version; using fallback"; exit 0 ;; esac
vndk=/apex/com.android.vndk.v$version/lib64
extract=
extract_mounted=
extract_loop=
cleanup_extract() {
    [ -n "$extract" ] || return 0
    if [ -n "$extract_mounted" ]; then
        umount "$extract/root" || { log "cannot unmount temporary VNDK"; return 1; }
        extract_mounted=
    fi
    if [ -n "$extract_loop" ]; then
        losetup -d "$extract_loop" || { log "cannot release temporary VNDK loop"; return 1; }
        extract_loop=
    fi
    rm -rf "$extract"
    extract=
}
trap cleanup_extract EXIT
trap 'exit 1' HUP INT TERM
if [ ! -d "$vndk" ]; then
    apex=/system_ext/apex/com.android.vndk.v$version.apex
    [ -f "$apex" ] || apex=/system_root/system/apex/com.android.vndk.v$version.apex
    [ -f "$apex" ] || apex=/system/apex/com.android.vndk.v$version.apex
    [ -f "$apex" ] || { log "VNDK apex missing"; exit 0; }
    extract="$hal/apex"
    mkdir -p "$extract" || exit 0
    # POSIX sh/mksh use 512-byte blocks: bound the payload to 64 MiB.
    # The limit applies to the writer, including a wrongly declared ZIP size.
    (ulimit -c 0 && ulimit -f 131072 &&
        exec /system/bin/7za e -y -o"$extract" "$apex" apex_payload.img) > "$hal/extract.log" 2>&1 || {
        log "cannot extract bounded VNDK payload; using fallback"
        exit 0
    }
    # APEX payloads may use ext4 or EROFS. debugfs reads ext4 without mounting.
    magic=$(dd if="$extract/apex_payload.img" bs=1 skip=1080 count=2 2>/dev/null | od -An -tx1 | tr -d ' \n')
    if [ "$magic" = 53ef ]; then
        mkdir -p "$extract/root/lib64" || exit 0
        # Keep all temporary library files within the remaining cache budget.
        temporary_remaining=$remaining
        for library in $vndk_libraries; do
            limit=$temporary_remaining
            [ "$limit" -le 8388608 ] || limit=8388608
            [ "$limit" -gt 0 ] || exit 0
            blocks=$((limit / 512))
            [ "$blocks" -gt 0 ] || exit 0
            (ulimit -c 0 && ulimit -f "$blocks" &&
                exec /system/bin/debugfs_static -R "dump /lib64/$library $extract/root/lib64/$library" \
                    "$extract/apex_payload.img") >> "$hal/extract.log" 2>&1 || exit 0
            size=$(stat -Lc %s "$extract/root/lib64/$library" 2>/dev/null) || exit 0
            case "$size" in ''|*[!0-9]*) exit 0 ;; esac
            [ "$size" -gt 0 ] && [ "$size" -le "$limit" ] || exit 0
            temporary_remaining=$((temporary_remaining - size))
        done
    else
        # The bundled fsck.erofs cannot select paths. Read the filesystem
        # without expanding it, then copy only the libraries listed above.
        mkdir -p "$extract/root" || exit 0
        extract_loop=$(losetup -f -s -r "$extract/apex_payload.img") || exit 0
        [ -n "$extract_loop" ] || exit 0
        mount -t erofs -o ro,nosuid,nodev,noexec "$extract_loop" "$extract/root" || {
            log "cannot mount VNDK EROFS; using fallback"
            exit 0
        }
        extract_mounted=true
    fi
    vndk="$extract/root/lib64"
fi
# Keep the ROM platform Binder ABI separate from its vendor VNDK ABI.
# In particular libutils/libc++ cannot safely be shared between these groups.
platform=
for root in /system_root/system/lib64 /system/lib64; do
    if [ -f "$root/libbinder_ndk.so" ]; then
        platform=$root
        break
    fi
done
[ -n "$platform" ] || { log "ROM platform libraries missing; using fallback"; exit 0; }
for library in libbinder.so libbinder_ndk.so liblog.so libapexsupport.so \
    libc++.so libutils.so libbase.so libcutils.so libprocessgroup.so \
    libcgrouprc.so libvndksupport.so; do
    copy_file "$platform/$library" "$hal/platform/$library" || {
        log "missing ROM platform library $library; using fallback"
        exit 0
    }
done
copy_file "$platform/libvndksupport.so" "$hal/lib64/libvndksupport.so" || exit 0
for library in $vndk_libraries; do
    [ -f "$vndk/$library" ] || {
        log "missing VNDK library $library; using fallback"
        rm -f "$hal/bin/"*
        exit 0
    }
    copy_file "$vndk/$library" "$hal/lib64/$library" || exit 0
done
cleanup_extract || exit 0
# The alias needs the ROM's effect table as well as its haptics firmware.
# A truncated table must not advertise a ready HAL.
for file in /vendor/firmware/*haptics* /vendor/firmware/aw869*.bin \
    /vendor/firmware/*_RTP.bin; do
    # Some ROM effect entries are empty placeholders rather than payloads.
    [ -s "$file" ] || continue
    copy_file "$file" "$cache/vendor/firmware/${file##*/}" || {
        log "cannot cache HAL effect $file; using fallback"
        exit 0
    }
done
chmod 0755 "$hal/bin/"*
printf '%s\n' "$kind" > "$hal/kind"
setprop twrp.haptics.kind "$kind"
log "cached $kind HAL and touch resources"
exit 0
