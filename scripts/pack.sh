#!/bin/bash

FILE_AFTER_PACK="after_pack.sh"
FILE_BOARD_AFTER_PACK="${ENTER_board_name}/${FILE_AFTER_PACK}"

DIR_SAVE_BOOT_FILE="${ENTER_board_name}/boot"

FILE_ROOTFS=""
FILE_BOOT_BIN=""
if [ -n "$UBOOT_CONFIG" ];then
    FILE_BOOT_BIN="${PATH_OUTPUT_BOARD}/${UBOOT_BIN_NAME}"
fi
if [ -n "$SYTERKIT_BOARD_FILE" ];then
    FILE_BOOT_BIN="${PATH_OUTPUT_BOARD}/$(basename $SYTERKIT_OUT_BIN)"
fi

MOUNT_DISK1="${PATH_TMP}/PART1"
MOUNT_DISK2="${PATH_TMP}/PART2"

IMG_FILE=""
PART1_SIZE=150
PART2_SIZE=0


exit_if_file_no_exsit() {
    if [ ! -f "$1" ]; then
        echo  $1 "no exist"
        exit 1
    fi
}

# 检查所需文件是不是都生成了
check_resource() {
    exit_if_file_no_exsit $FILE_ROOTFS
    exit_if_file_no_exsit $FILE_BOOT_BIN
    
}




do_pack() {
    [[ ! -d $MOUNT_DISK1 ]] && mkdir -p $MOUNT_DISK1
    [[ ! -d $MOUNT_DISK2 ]] && mkdir -p $MOUNT_DISK2
    # mkdir -p $MOUNT_DISK1
    # mkdir -p $MOUNT_DISK2
    FILE_ROOTFS="$OUTFILE_rootfs_tar"
    cd ${PATH_SOURCE}/wpi-update
    VERSION_APT=""
    # run_status "get wpi-update version"
    VERSION_APT=$(echo $(./wpi-update -s | tail -n 1 ))
    


    IMG_FILE="${PATH_OUTPUT}/V${VERSION_APT}_$(date +%m-%d)_${ENTER_rootfs_type}_${BOARD_NAME}_${LINUX_BRANCH}_${ENTER_os_ver}"
    if [ -f "$IMG_FILE" ]; then
        rm ${IMG_FILE}
    fi
    # echo "开始打包"
    check_resource
    
    ROOTFS_SIZE=$(du -sm $TMP_rootfs_build | cut -f1)
    PART2_SIZE=$((ROOTFS_SIZE + 500))
    
    echo "PART1_SIZE=${PART1_SIZE}MB"
    echo "PART2_SIZE=${PART2_SIZE}MB"
    
    # 创建img文件
    IMG_SIZE=$((PART1_SIZE + PART2_SIZE + 2 ))
    run_status "create img file: $IMG_FILE " dd if=/dev/zero of=$IMG_FILE bs=1M count=$IMG_SIZE
    
    # 创建分区
    echo "创建分区"
    parted $IMG_FILE --script mklabel msdos
    parted $IMG_FILE --script mkpart primary fat32 1M $((PART1_SIZE + 1))M
    parted $IMG_FILE --script mkpart primary ext4 $((PART1_SIZE + 1))M 100%
    parted $IMG_FILE set 1 boot on
    
    LOOP_DEVICE=$(sudo losetup -f)
    
    losetup $LOOP_DEVICE $IMG_FILE
    kpartx -av $LOOP_DEVICE
    
    # 挂载镜像文件
    MAPPER_DEVICE=$(echo $LOOP_DEVICE | sed 's/\/dev\///' | sed 's/\//p/')
    MAPPER_DEVICE1="/dev/mapper/${MAPPER_DEVICE}p1"
    MAPPER_DEVICE2="/dev/mapper/${MAPPER_DEVICE}p2"
    
    # echo "开始格式化"
    run_status "format part 1" mkfs.vfat $MAPPER_DEVICE1
    run_status "format part 2" mkfs.ext4 $MAPPER_DEVICE2
    
    
    BOOT_UUID=$(blkid -s UUID -o value $MAPPER_DEVICE1)
    BOOT_PARTUUID=$(blkid -s PARTUUID -o value $MAPPER_DEVICE1)
    ROOTFS_UUID=$(blkid -s UUID -o value $MAPPER_DEVICE2)
    ROOTFS_PARTUUID=$(blkid -s PARTUUID -o value $MAPPER_DEVICE2)
    
    
    # echo "装载文件到img"
    run_status "add $BOOTLOADER_NAME" dd if=$FILE_BOOT_BIN of=$IMG_FILE bs=1K seek=8 conv=notrunc
    
    mount $MAPPER_DEVICE1 $MOUNT_DISK1
    mount $MAPPER_DEVICE2 $MOUNT_DISK2
    
    # echo "output之前生成的文件"
    run_status "add rootfs" tar xf  $FILE_ROOTFS -C $MOUNT_DISK2  -I 'xz -T0'
    run_status "move part2/boot to part1" mv $MOUNT_DISK2/boot/*  $MOUNT_DISK1

    # 装入本项目保存的bin文件
    echo "DIR_SAVE_BOOT_FILE=$DIR_SAVE_BOOT_FILE"
    if [ -d $DIR_SAVE_BOOT_FILE ]; then
        run_status "add files to part1" cp -r $DIR_SAVE_BOOT_FILE/* $MOUNT_DISK1
    fi


    # 写入uuid
    echo "rootdev=PARTUUID=${ROOTFS_PARTUUID}" | sudo tee -a ${MOUNT_DISK1}/config.txt
    echo "PARTUUID=${ROOTFS_PARTUUID} / ext4 defaults,acl,noatime,commit=600,errors=remount-ro 0 1" | sudo tee -a ${MOUNT_DISK2}/etc/fstab
    echo "PARTUUID=${BOOT_PARTUUID} /boot vfat defaults 0 0" | sudo tee -a ${MOUNT_DISK2}/etc/fstab
    
    mount $MAPPER_DEVICE1 $MOUNT_DISK2/boot
    
    SOURCE_kernel="${PATH_SOURCE}/$(basename "$LINUX_GIT" .git)-$LINUX_BRANCH"
    kernel_version=$(get_linux_version $SOURCE_kernel)
    run_status_no_retry "generate initramfs" chroot $MOUNT_DISK2 /bin/bash -c "DEBIAN_FRONTEND=noninteractive  update-initramfs -uv -k $kernel_version"
    
    
    # 运行板子自带的脚本
    if [ -f $FILE_BOARD_AFTER_PACK ]; then
        cp $FILE_BOARD_AFTER_PACK  ${MOUNT_DISK2}/opt/${FILE_AFTER_PACK}
        run_status "run ${FILE_AFTER_PACK}" chroot $MOUNT_DISK2 /bin/bash -c "DEBIAN_FRONTEND=noninteractive  bash  /opt/${FILE_AFTER_PACK}"
        rm ${MOUNT_DISK2}/opt/${FILE_AFTER_PACK}
    fi
    
    umount $MOUNT_DISK2/boot
    
    umount $MOUNT_DISK1
    umount $MOUNT_DISK2
    kpartx -dv $LOOP_DEVICE
    losetup -d $LOOP_DEVICE
    
    current_hour=$(date +"%H")
    current_minute=$(date +"%M")
    formatted_hour=$(printf "%02d" "$current_hour")
    formatted_minute=$(printf "%02d" "$current_minute")

    NEW_IMG_FILE_NAME="${IMG_FILE}--${formatted_hour}_${formatted_minute}.img"
    mv $IMG_FILE $NEW_IMG_FILE_NAME

    echo -e "\noutputfile:\n\n\t\033[32m$(du -h ${NEW_IMG_FILE_NAME})\033[0m\n\n"
    
}

