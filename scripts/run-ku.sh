#!/bin/sh

# This script is used safely start and stop Kobo-UNCaGED.
# It handles entering and exiting USBMS mode, mounting and dismounting the onboard partition, and killing and restoring WiFi

# Some parts of this script, and all scripts in "koreader-scripts" come from Koreader. The source of these scripts is
# https://github.com/koreader/koreader/tree/master/platform/kobo which are licenced under the AGPL 3.0 licence

# Include our USBMS library
KU_DIR="$1"
KU_TMP_DIR="$2"
. ./nickel-usbms.sh

logmsg "N" "Entering USBMS mode..."
logmsg "I" "Inserting USB"
insert_usb

logmsg "I" "Scanning for Button"
BS_TIMEOUT=0
while ! ./button_scan -p
do
    # If the button scan hasn't succeeded in 5 seconds, assume it's not going to...
    if [ $BS_TIMEOUT -ge 20 ]; then
        exit 1
    fi
    # Button scan hasn't succeeded yet. wait a bit (250ms), then try again
    usleep 250000
    BS_TIMEOUT=$(( BS_TIMEOUT + 1 ))
done
logmsg "I" "(Re)mounting onboard"
if ! mount_onboard; then
    logmsg "C" "Onboard did not remount"
    remove_usb
    exit 1

fi
logmsg "I" "Enabling WiFi"
if ! enable_wifi; then
    logmsg "C" "WiFi did not enable. Aborting!"
    unmount_onboard
    remove_usb
    exit 1
fi

logmsg "N" "USBMS mode entered..."

logmsg "I" "Running Kobo-UNCaGED"
KU_BIN="${MNT_ONBOARD_NEW}/${KU_DIR}/bin/kobo-uncaged"
$KU_BIN "-onboardmount=${MNT_ONBOARD_NEW}"
KU_RES=$?
logmsg "N" "Leaving USBMS..."
logmsg "I" "Disabling WiFi"
disable_wifi
logmsg "N" "WiFi disabled..."
logmsg "I" "Unmounting onboard"
unmount_onboard
logmsg "N" "Onboard unmounted..."

./button_scan -w -u -q
BS_RES=$?
if [ $KU_RES -eq 1 ] && $BS_RES; then
    logmsg "I" "Updating metadata"
    logmsg "N" "Entering USBMS mode..."
    insert_usb

    BS_TIMEOUT=0
    while ! ./button_scan -p -q
    do
        # If the button scan hasn't succeeded in 5 seconds, assume it's not going to...
        if [ $BS_TIMEOUT -ge 20 ]; then
            exit 1
        fi
        # Button scan hasn't succeeded yet. wait a bit (250ms), then try again
        usleep 250000
        BS_TIMEOUT=$(( BS_TIMEOUT + 1 ))
    done
    if ! mount_onboard; then
        remove_usb
        exit 1
    fi
    $KU_BIN "-onboardmount=${MNT_ONBOARD_NEW}" "-metadata"
    unmount_onboard
    logmsg "N" "Onboard unmounted..."
    remove_usb
fi

