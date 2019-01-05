# openWrt
Learning, setting up and playing with openWrt


# Wireless Bridge
Once openWrt installed, this script sets up a basic wireless bridge router to a host AP (as given by e.g., (smartphone) hotspot, cable, ...)

Tested on a Linksys WRT1900AC ver1 router connecting to a smartphone hotspot

The README-wirelessBridge contains a detail explanation of howto, what and why for setting up a router as a wireless bridge (basic configuration)

The HELP-wirelessBridge contains the usage information of main script openwrt-setup-wirelessbridge.sh and stages it performs

The Minimized version contains a sequential version of the main script w/ only commands and notifications.

The Bare version is a Just-do-it, no questions asked version. Requires defining a few variables at the beginning of the script, e.g., SSID, AP passphrase, channel, etc.
