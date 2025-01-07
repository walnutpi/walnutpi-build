#!/bin/bash


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
    if [ ! -d "$OUTDIR_boot_package" ]; then
        echo  $OUTDIR_boot_package "no exist"
        exit
    fi
    if [ ! -d "$OUTDIR_kernel_package" ]; then
        echo  $OUTDIR_kernel_package "no exist"
        exit
    fi
    if [ ! -f "$OUTFILE_rootfs_tar" ]; then
        echo  $OUTFILE_rootfs_tar "no exist"
        exit
    fi
}




build_image() {
    cleanup() {
        local LOOP_DEVICE=$1
        echo "Cleaning up..."
        cd $PATH_PROJECT_DIR
        if mountpoint -q "$TMP_mount_disk2/boot"; then
            echo "Unmounting $TMP_mount_disk2/boot"
            while mountpoint -q "$TMP_mount_disk2/boot"; do
                umount "$TMP_mount_disk2/boot"
                sleep 1
            done
        fi
        if mountpoint -q "$TMP_mount_disk1"; then
            echo "Unmounting $TMP_mount_disk1"
            while mountpoint -q "$TMP_mount_disk1"; do
                umount "$TMP_mount_disk1"
                sleep 1
            done
        fi
        if mountpoint -q "$TMP_mount_disk2"; then
            echo "Unmounting $TMP_mount_disk2"
            while mountpoint -q "$TMP_mount_disk2"; do
                umount "$TMP_mount_disk2"
                sleep 1
            done
        fi
        
        if [ ! -z "$LOOP_DEVICE" ]; then
            if losetup -l > /dev/null 2>&1; then
                while losetup -l | grep -q "$LOOP_DEVICE"; do
                    echo "Releasing loop device $LOOP_DEVICE"
                    kpartx -dv "$LOOP_DEVICE"
                    losetup -d "$LOOP_DEVICE"
                    sleep 1
                done
            fi
        fi
    }
    
    trap 'cleanup "$LOOP_DEVICE"; exit' SIGINT
    check_resource
    if [  -d $TMP_mount_disk1 ]; then
        rm -r $TMP_mount_disk1
    fi
    if [ -d $TMP_mount_disk2 ]; then
        rm -r $TMP_mount_disk2
    fi
    mkdir -p $TMP_mount_disk1
    mkdir -p $TMP_mount_disk2
    
    cd ${PATH_SOURCE}/wpi-update
    echo -n "$BOARD_MODEL" > /tmp/walnutpi-board_model
    VERSION_APT=$(echo $(./wpi-update -s | tail -n 1 ))
    reload_env
    if [ -f "$OUT_IMG_FILE" ]; then
        rm ${OUT_IMG_FILE}
    fi
    
    local ROOTFS_SIZE=$(du -sm $TMP_rootfs_build | cut -f1)
    local PART2_SIZE=$((ROOTFS_SIZE + 800))
    
    echo "PART1_SIZE=${PART1_SIZE}MB"
    echo "PART2_SIZE=${PART2_SIZE}MB"
    
    # 创建img文件
    IMG_SIZE=$((PART1_SIZE + PART2_SIZE + 2 ))
    run_status "create img file: $OUT_IMG_FILE $IMG_SIZE MB" dd if=/dev/zero of=$OUT_IMG_FILE bs=1M count=$IMG_SIZE
    
    # 创建分区
    echo "创建分区"
    parted $OUT_IMG_FILE --script mklabel msdos
    parted $OUT_IMG_FILE --script mkpart primary fat32 1M $((PART1_SIZE + 1))M
    parted $OUT_IMG_FILE --script mkpart primary ext4 $((PART1_SIZE + 1))M 100%
    parted $OUT_IMG_FILE set 1 boot on
    
    LOOP_DEVICE=$(sudo losetup -f)
    
    losetup $LOOP_DEVICE $OUT_IMG_FILE
    kpartx -av $LOOP_DEVICE
    
    # 挂载镜像文件
    MAPPER_DEVICE=$(echo $LOOP_DEVICE | sed 's/\/dev\///' | sed 's/\//p/')
    MAPPER_DEVICE1="/dev/mapper/${MAPPER_DEVICE}p1"
    MAPPER_DEVICE2="/dev/mapper/${MAPPER_DEVICE}p2"
    echo "MAPPER_DEVICE=${MAPPER_DEVICE}"
    
    # echo "开始格式化"
    run_status "format part 1" mkfs.vfat $MAPPER_DEVICE1
    run_status "format part 2" mkfs.ext4 $MAPPER_DEVICE2
    
    
    BOOT_UUID=$(blkid -s UUID -o value $MAPPER_DEVICE1)
    BOOT_PARTUUID=$(blkid -s PARTUUID -o value $MAPPER_DEVICE1)
    ROOTFS_UUID=$(blkid -s UUID -o value $MAPPER_DEVICE2)
    ROOTFS_PARTUUID=$(blkid -s PARTUUID -o value $MAPPER_DEVICE2)
    
    # 挂载两个分区
    mount $MAPPER_DEVICE1 $TMP_mount_disk1
    mount $MAPPER_DEVICE2 $TMP_mount_disk2
    if [ ! -d $TMP_mount_disk2/boot ]; then
        mkdir -p $TMP_mount_disk2/boot
    fi
    mount $MAPPER_DEVICE1 $TMP_mount_disk2/boot
    
    # 导入文件
    run_status "add $BOOTLOADER_NAME" dd if=$OUTFILE_boot_bin of=$OUT_IMG_FILE bs=1K seek=8 conv=notrunc
    run_status "add rootfs" tar xf  $OUTFILE_rootfs_tar -C $TMP_mount_disk2  -I 'xz -T0'
    
    # 安装boot相关的deb包
    cp ${OUTDIR_boot_package}/*.deb  ${TMP_mount_disk2}/opt/
    cd ${TMP_mount_disk2}/opt/
    deb_packages=(*.deb)
    total=${#deb_packages[@]}
    for (( i=0; i<$total; i++ )); do
        deb_package=${deb_packages[$i]}
        run_status "boot package [$((i+1))/${total}] : ${deb_package} " chroot ${TMP_mount_disk2} /bin/bash -c "dpkg -i /opt/${deb_package}"
        #  chroot ${TMP_mount_disk2} /bin/bash -c "dpkg -i /opt/${deb_package}"
        rm ${TMP_mount_disk2}/opt/${deb_package}
    done
    
    # 安装kernel产生的的deb包，先安装生成时间早的
    cd ${OUTDIR_kernel_package}/
    deb_packages=($(ls -t *.deb | tac))
    cp ${OUTDIR_kernel_package}/*.deb  ${TMP_mount_disk2}/opt/
    cd ${TMP_mount_disk2}/opt/
    total=${#deb_packages[@]}
    for (( i=0; i<$total; i++ )); do
        deb_package=${deb_packages[$i]}
        run_status "kernel package [$((i+1))/${total}] : ${deb_package} " chroot ${TMP_mount_disk2} /bin/bash -c "dpkg -i /opt/${deb_package}"
        rm ${TMP_mount_disk2}/opt/${deb_package}
    done
    
    # 写入uuid
    echo "rootdev=PARTUUID=${ROOTFS_PARTUUID}" | sudo tee -a ${TMP_mount_disk1}/config.txt
    echo "PARTUUID=${ROOTFS_PARTUUID} / ext4 defaults,acl,noatime,commit=600,errors=remount-ro 0 1" | sudo tee -a ${TMP_mount_disk2}/etc/fstab
    echo "PARTUUID=${BOOT_PARTUUID} /boot vfat defaults 0 0" | sudo tee -a ${TMP_mount_disk2}/etc/fstab
    
    
    SOURCE_kernel="${PATH_SOURCE}/$(basename "$LINUX_GIT" .git)-$LINUX_BRANCH"
    kernel_version=$(get_linux_version $SOURCE_kernel)
    # run_status_no_retry "generate initramfs" chroot $TMP_mount_disk2 /bin/bash -c "DEBIAN_FRONTEND=noninteractive  update-initramfs -uv -k $kernel_version"
    echo ""generate initramfs""
    run_as_silent chroot $TMP_mount_disk2 /bin/bash -c "DEBIAN_FRONTEND=noninteractive  update-initramfs -uv -k $kernel_version"
    
    trap - SIGINT EXIT
    cleanup "$LOOP_DEVICE"
    
    current_hour=$(date +"%H")
    current_minute=$(date +"%M")
    formatted_hour=$(printf "%02d" "$current_hour")
    formatted_minute=$(printf "%02d" "$current_minute")
    
    NEW_IMG_FILE_NAME="${OUT_IMG_FILE}--${formatted_hour}_${formatted_minute}.img"
    mv $OUT_IMG_FILE $NEW_IMG_FILE_NAME
    
    echo -e "\noutputfile:\n\n\t\033[32m$(du -h ${NEW_IMG_FILE_NAME})\033[0m\n\n"
    
}

