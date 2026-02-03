#!/bin/sh
case "$1" in
    configure)
        old_version="$2"
        new_version="$3"
        echo "Updating from version $old_version to version $new_version"

        cp -r $path_board_tmp_boot/* /boot/
        set-device

        BLOCK_DEVICE=$(findmnt "/" -o SOURCE -n)
        ROOTFS_PARTUUID=$(blkid -s PARTUUID -o value $BLOCK_DEVICE)
        if [ -z "$ROOTFS_PARTUUID" ]; then
            echo "无法解析出uuid"
            exit
        fi
        echo "rootdev=PARTUUID=${ROOTFS_PARTUUID}" | sudo tee -a /boot/config.txt

        ;;
    abort-upgrade|abort-remove|abort-deconfigure)
        # 回滚操作
        ;;

esac
exit 0