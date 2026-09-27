# Recovery Wi-Fi Runtime

This directory contains the optional Wi-Fi runtime for the `twrp_taro_wifi`
product. It is not included in the base `twrp_taro` product.

The runtime connects TWRP's WLAN interface to the vendor Wi-Fi stack through
the QTI HIDL Wi-Fi HAL. It includes the recovery service definition, vendor
Wi-Fi libraries and firmware configuration, kernel modules, a recovery-only
`wpa_supplicant`, and the control and DHCP helpers used by TWRP's network UI.

## Runtime Behavior

- Starts the vendor Wi-Fi HAL and `wpa_supplicant` when Wi-Fi is enabled. The
  init service is named `wpa_supplicant` and prepares the runtime itself, so
  the recovery UI can start and stop it with `ctl.start`/`ctl.stop`. The UI
  then runs the `dhcpcd` that TWRP installs with `TW_INCLUDE_WIFI`.
- Uses `wlan0` and a recovery-local control socket under
  `/tmp/recovery/sockets`.
- Publishes the active address, gateway and DNS values through recovery network
  properties.
- Stops the supplicant and clears network state when Wi-Fi is disabled while
  retaining the vendor HAL and kernel modules for reuse.
- Uses `update_config=0`, so credentials configured in recovery are held by the
  running process and are not written to the recovery image or persistent
  storage.

## Hardware Scope

The prebuilt HAL, firmware configuration and kernel modules target the
`marble` vendor Wi-Fi implementation based on Qualcomm QCA6490. They are
hardware-specific and are not a generic Wi-Fi stack for every device in the
`taro` family.

Using Wi-Fi on another device requires matching vendor libraries, firmware,
kernel modules, init definitions and VINTF declarations.

See the [parent device-tree README](../README.md) for the overall recovery
project and product layout.
