#!/bin/sh
case "$1" in
configure)
    old_version="$2"
    new_version="$3"
    echo "Updating from version $old_version to version $new_version"
    cp -r /tmp-boot/boot-configtxt/* /boot/

    BLOCK_DEVICE=$(findmnt "/boot" -o SOURCE -n)
    echo "BLOCK_DEVICE=$BLOCK_DEVICE"
    BASE_DEVICE=$(echo "$BLOCK_DEVICE" | sed -E 's/p[0-9]+$//')
    if [ -z "$BASE_DEVICE" ]; then
        echo "无法解析出块设备路径"
        exit
    fi
    if [ -f /boot/boot.bin ]; then
        dd_command="dd if=/boot/boot.bin of=$BASE_DEVICE bs=1K seek=8 conv=notrunc"
        echo "$dd_command"
        eval $dd_command
    fi
    if [ -f /boot/boot_1M.bin ]; then
        dd_command="dd if=/boot/boot_1M.bin of=$BASE_DEVICE bs=1 seek=1M conv=notrunc"
        echo "$dd_command"
        eval $dd_command
    fi
    if [ -f /boot/boot_2M.bin ]; then
        dd_command="dd if=/boot/boot_2M.bin of=$BASE_DEVICE bs=1 seek=2M conv=notrunc"
        echo "$dd_command"
        eval $dd_command
    fi
    ;;
abort-upgrade | abort-remove | abort-deconfigure)
    # 回滚操作
    ;;
*)
    exit 1
    ;;
esac

exit 0
