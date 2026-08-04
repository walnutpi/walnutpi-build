#!/bin/sh
set -e
case "$1" in
    configure)
        old_version="$2"
        new_version="$3"
        echo "Updating from version $old_version to version $new_version"
        cp -r /tmp-boot/Image/* /boot/
        ;;
    abort-upgrade|abort-remove|abort-deconfigure)
        ;;
    *)
        exit 1
        ;;
esac
