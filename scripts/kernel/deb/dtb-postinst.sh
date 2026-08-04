#!/bin/sh
set -e
case "$1" in
    configure)
        old_version="$2"
        new_version="$3"
        echo "Updating from version $old_version to version $new_version"
        cp -r /tmp-boot/dtb/* /boot/
        set-device
        echo "ok"
        ;;
    abort-upgrade|abort-remove|abort-deconfigure)
        ;;
    *)
        exit 1
        ;;
esac
