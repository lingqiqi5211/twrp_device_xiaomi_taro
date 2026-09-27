# TWRP Device Tree for Xiaomi Taro

An unofficial TWRP 16 device tree for Xiaomi devices in the `taro` platform
family. It provides a common arm64, ramdisk-only A/B recovery image for several
Xiaomi, Redmi and POCO products, with device identity and hardware-specific
modules selected at runtime.

## Target Devices

The shared product definitions cover the following device codenames:

| Codename   | Device                           | SoC    |
| ---------- | -------------------------------- | ------ |
| `marble`   | Redmi Note 12 Turbo / POCO F5    | SM7475 |
| `mayfly`   | Xiaomi 12S                       | SM8475 |
| `mondrian` | Redmi K60 / POCO F5 Pro          | SM8475 |
| `diting`   | Redmi K50 Ultra / Xiaomi 12T Pro | SM8475 |
| `unicorn`  | Xiaomi 12S Pro                   | SM8475 |
| `thor`     | Xiaomi 12S Ultra                 | SM8475 |
| `cupid`    | Xiaomi 12                        | SM8450 |
| `zeus`     | Xiaomi 12 Pro                    | SM8450 |
| `ingres`   | Redmi K50 Gaming / POCO F4 GT    | SM8450 |

The `marble` hardware profile is the primary integrated target. Other codenames
share the common recovery framework but may require their own touch firmware,
vendor modules and device-specific files.

## Features

- TWRP 16 recovery userspace based on Android 16/API 36 sources
- arm64 A/B recovery with dynamic-partition and fastbootd support
- File-based encryption and metadata encryption using fscrypt policy v2
- QTI Keymaster, KeyMint, Gatekeeper and boot-control services, and the AOSP
  AIDL health service
- ADB, MTP, sideload, USB OTG and recovery partition tools
- EROFS logical partitions and Android Verified Boot support
- Runtime device identification for regional Xiaomi, Redmi and POCO models
- Touch-module selection for different vendor kernel configurations
- ZIP64-aware extraction for large update packages
- Optional Wi-Fi-enabled product using the runtime in [`wifi/`](wifi/)

## Products

| Product            | Description                                          |
| ------------------ | ---------------------------------------------------- |
| `twrp_taro`        | Base recovery product without the Wi-Fi runtime      |
| `twrp_taro_wifi`   | Optional recovery product with WLAN support enabled |

The two products share the same recovery framework. Wi-Fi is kept out of the
base product because its HAL, firmware and kernel modules are vendor-specific.

## Clone and Build

Build on a Linux x86_64 host with `repo`, Git, Java and the standard Android
build dependencies. TWRP 16 requires at least 16 GiB of RAM and about 120 GiB
of free disk space.

### Clone the Sources

Initialize a TWRP 16 source tree and sync the base projects:

```bash
mkdir -p ~/android/twrp-taro
cd ~/android/twrp-taro

repo init \
    -u https://github.com/TWRP-Test/platform_manifest_twrp_aosp.git \
    -b twrp-16.0 \
    --depth=1 \
    --no-clone-bundle \
    --partial-clone \
    --clone-filter=blob:limit=10M
repo sync \
    -c \
    --fail-fast \
    --force-sync \
    --no-clone-bundle \
    --no-tags \
    --optimized-fetch \
    --prune \
    -j2
```

Clone this device tree into the standard Android source layout, then install
its local manifest. The manifest selects the recovery source required by this
tree and restores `frameworks/libs/native_bridge_support`:

```bash
git clone \
    https://github.com/lingqiqi5211/twrp_device_xiaomi_taro.git \
    device/xiaomi/taro

mkdir -p .repo/local_manifests
cp device/xiaomi/taro/manifests/taro-twrp16.xml .repo/local_manifests/
repo sync \
    -c \
    --fail-fast \
    --force-sync \
    --no-clone-bundle \
    --no-tags \
    --optimized-fetch \
    --prune \
    bootable/recovery frameworks/libs/native_bridge_support
```

### Build the Recovery

Run the build script from the Android source root. It installs the device tree
when needed, checks the recovery source, selects the product and builds the
recovery image:

```bash
cd ~/android/twrp-taro
TWRP_PRODUCT=twrp_taro \
    bash device/xiaomi/taro/scripts/build.sh
```

To build the optional Wi-Fi product instead:

```bash
TWRP_PRODUCT=twrp_taro_wifi \
    bash device/xiaomi/taro/scripts/build.sh
```

The generated images are placed at:

- `out/target/product/taro/recovery.img`
- `out-taro-wifi/target/product/taro/recovery.img`

## References

This tree follows the structure and conventions used by the following projects:

- [TWRP](https://twrp.me/)
- [TWRP AOSP platform manifest](https://github.com/TWRP-Test/platform_manifest_twrp_aosp)
- [AviderMin/ofrp_device_xiaomi_marble](https://github.com/AviderMin/ofrp_device_xiaomi_marble)
- [YuKongA/device_xiaomi_marble_TWRP](https://github.com/YuKongA/device_xiaomi_marble_TWRP)
- [YuKongA/twrp_device_xiaomi_sm8850](https://github.com/YuKongA/twrp_device_xiaomi_sm8850)
- [Kyuofox/twrp_device_xiaomi_sm8850](https://github.com/Kyuofox/twrp_device_xiaomi_sm8850)

This is an unofficial community project and is not affiliated with Xiaomi or
Team Win Recovery Project.
