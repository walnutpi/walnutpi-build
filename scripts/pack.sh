#!/bin/bash

FILE_ROOTFS=""
FILE_IMAGE="${PATH_OUTPUT}/Image"
FILE_UBOOT="${PATH_OUTPUT}/${UBOOT_BIN_NAME}"

MOUNT_DISK1="${PATH_TMP}/PART1"
MOUNT_DISK2="${PATH_TMP}/PART2"

IMG_FILE=""
PART1_SIZE=100
PART2_SIZE=0


# 检查所需文件是不是都生成了
check_resource() {
    local dirs=("$FILE_ROOTFS" "$FILE_IMAGE" "$FILE_UBOOT")
    for dir in "${dirs[@]}"; do
        echo $dir
        if [ ! -f "$dir" ]; then
            echo "no exist"
            exit 1
        fi
    done
    
}




do_pack() {
    
    mkdir -p $MOUNT_DISK1
    mkdir -p $MOUNT_DISK2
    FILE_ROOTFS="$FILE_ROOTFS_TAR"
    
    IMG_FILE="${PATH_OUTPUT}/V$(cat $PATH_PWD/VERSION)_$(date +%m-%d)_${OPT_ROOTFS_TYPE}_${BOARD_NAME}_${LINUX_BRANCH}_${OPT_OS_VER}.img"
    # IMG_FILE="${PATH_OUTPUT}/V$(cat $PATH_PWD/VERSION)_${BOARD_NAME}_${LINUX_BRANCH}_${OPT_OS_VER}_${OPT_ROOTFS_TYPE}.img"
    if [ -f "$IMG_FILE" ]; then
        rm ${IMG_FILE}
    fi
    # echo "开始打包"
    check_resource
    
    ROOTFS_SIZE=$(du -sm $PATH_ROOTFS | cut -f1)
    PART2_SIZE=$((ROOTFS_SIZE + 200))
    
    echo "PART1_SIZE=${PART1_SIZE}MB"
    echo "PART2_SIZE=${PART2_SIZE}MB"
    
    # 创建img文件
    IMG_SIZE=$((PART1_SIZE + PART2_SIZE + 2 ))
    run_status "create img file" dd if=/dev/zero of=$IMG_FILE bs=1M count=$IMG_SIZE
    
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
    run_status "add uboot" dd if=$FILE_UBOOT of=$IMG_FILE bs=1K seek=8 conv=notrunc
    
    mount $MAPPER_DEVICE1 $MOUNT_DISK1
    mount $MAPPER_DEVICE2 $MOUNT_DISK2
    
    
    # echo "output之前生成的文件"
    run_status "add kernel" cp $FILE_IMAGE $MOUNT_DISK1
    run_status "add rootfs" tar xf $FILE_ROOTFS -C $MOUNT_DISK2
    
    run_status "boot.scr" mkimage -C none -A arm -T script -d ${PATH_BOOTFILE}/boot.cmd ${PATH_BOOTFILE}/boot.scr
    cp ${PATH_BOOTFILE}/boot.cmd $MOUNT_DISK1
    cp ${PATH_BOOTFILE}/boot.scr $MOUNT_DISK1
    cp ${CONF_DIR}/config.txt $MOUNT_DISK1
    
    run_status "device-tree" cp -r ${PATH_OUTPUT}/dtb/allwinner/* $MOUNT_DISK1
    mv $MOUNT_DISK1/overlay $MOUNT_DISK1/overlays
    
    # 写入uuid
    echo "rootdev=PARTUUID=${ROOTFS_PARTUUID}" | sudo tee -a ${MOUNT_DISK1}/config.txt
    echo "PARTUUID=${ROOTFS_PARTUUID} / ext4 defaults,noatime,commit=600,errors=remount-ro 0 1" | sudo tee -a ${MOUNT_DISK2}/etc/fstab
    echo "PARTUUID=${BOOT_PARTUUID} /boot vfat defaults 0 0" | sudo tee -a ${MOUNT_DISK2}/etc/fstab
    
    mount $MAPPER_DEVICE1 $MOUNT_DISK2/boot
    cp -r $PATH_S_FS_PACK/* $MOUNT_DISK2/opt
    
    
    declare -a files_array
    for file in ${MOUNT_DISK2}/opt/*.sh; do
        files_array+=("${file}")
    done
    
    for (( i=0; i<${#files_array[@]}; i++ )); do
        file=${files_array[$i]}
        chmod +x $file
        file_name=$(basename -- "${file}")
        # echo "running script [$((i+1))/${#files_array[@]}] $file_name"
        run_status "running script [$((i+1))/${#files_array[@]}] $file_name" chroot  $MOUNT_DISK2 /bin/bash -c "export HOME=/root; cd /opt/ && ./${file_name}"
        rm $file
    done
    
    
    umount $MOUNT_DISK2/boot
    
    umount $MOUNT_DISK1
    umount $MOUNT_DISK2
    kpartx -dv $LOOP_DEVICE
    losetup -d $LOOP_DEVICE
    
    echo -e "\noutputfile:\n\n\t\033[32m${IMG_FILE}\033[0m\n\n"
    
}

