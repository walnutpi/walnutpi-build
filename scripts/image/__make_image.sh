#!/bin/bash
# scripts/image/__make_image.sh
# 阶段2：从临时目录创建最终的镜像文件
#
# 职责：
#   1. 计算 rootfs 大小，确定分区和镜像尺寸
#   2. 创建空白镜像文件并分区（msdos + fat32 + ext4）
#   3. 申请 loop 设备并挂载镜像分区
#   4. 写入 bootloader 到镜像
#   5. 将临时目录内容拷贝到镜像分区
#   6. 写入 PARTUUID 配置（config.txt / fstab）
#   7. 生成 initramfs
#   8. 卸载、清理 loop 设备，重命名输出镜像

__create_img_file() {
    local OUT_IMG_FILE=$1
    local IMG_SIZE=$2
    local PART1_SIZE=$3

    if [ -f "$OUT_IMG_FILE" ]; then
        rm ${OUT_IMG_FILE}
    fi
    run_status "create img file: $OUT_IMG_FILE $IMG_SIZE MB" dd if=/dev/zero of=$OUT_IMG_FILE bs=1M count=$IMG_SIZE
    echo "创建分区"
    parted $OUT_IMG_FILE --script mklabel msdos
    parted $OUT_IMG_FILE --script mkpart primary fat32 4M $((PART1_SIZE + 1))M
    parted $OUT_IMG_FILE --script mkpart primary ext4 $((PART1_SIZE + 1))M 100%
    parted $OUT_IMG_FILE set 1 boot on
}

__get_new_img_file_name() {
    local OUT_IMG_FILE=$1

    local current_hour=$(date +"%H")
    local current_minute=$(date +"%M")
    local formatted_hour=$(printf "%02d" "$current_hour")
    local formatted_minute=$(printf "%02d" "$current_minute")

    NEW_IMG_FILE_NAME="${OUT_IMG_FILE}--${formatted_hour}_${formatted_minute}.img"
    echo "${NEW_IMG_FILE_NAME}"
}

__mount_img_to_dir() {
    local OUT_IMG_FILE=$1
    local TMP_mount_disk1=$2
    local TMP_mount_disk2=$3

    LOOP_DEVICE=""
    local MAX_RETRIES=5
    local RETRY_COUNT=0

    # 循环获取可用 loop 设备并关联镜像文件
    until [ -n "$LOOP_DEVICE" ] && [ -b "$LOOP_DEVICE" ]; do
        LOOP_DEVICE=$(losetup -f)
        if [ $? -ne 0 ] || [ -z "$LOOP_DEVICE" ]; then
            RETRY_COUNT=$((RETRY_COUNT + 1))
            if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
                echo "Error: Failed to get a loop device after $MAX_RETRIES attempts."
                exit 1
            fi
            echo "Warning: Failed to get loop device, retrying in 3 second... ($RETRY_COUNT/$MAX_RETRIES)"
            sleep 3
            continue
        fi

        losetup "$LOOP_DEVICE" "$OUT_IMG_FILE"
        if [ $? -ne 0 ]; then
            RETRY_COUNT=$((RETRY_COUNT + 1))
            if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
                echo "Error: Failed to setup loop device after $MAX_RETRIES attempts."
                exit 1
            fi
            echo "Warning: Failed to setup $LOOP_DEVICE with $OUT_IMG_FILE, retrying in 1 second... ($RETRY_COUNT/$MAX_RETRIES)"
            kpartx -dv "$LOOP_DEVICE"
            losetup -d "$LOOP_DEVICE"
            sleep 3
            LOOP_DEVICE="" # 清除无效设备路径
        fi
    done

    kpartx -av "$LOOP_DEVICE"

    # 挂载镜像文件
    local MAPPER_DEVICE=$(echo "$LOOP_DEVICE" | sed 's/\/dev\///' | sed 's/\//p/')
    MAPPER_DEVICE1="/dev/mapper/${MAPPER_DEVICE}p1"
    MAPPER_DEVICE2="/dev/mapper/${MAPPER_DEVICE}p2"
    echo "MAPPER_DEVICE=${MAPPER_DEVICE}"

    run_status "format part 1" mkfs.vfat "$MAPPER_DEVICE1"
    run_status "format part 2" mkfs.ext4 "$MAPPER_DEVICE2"

    mount "$MAPPER_DEVICE1" "$TMP_mount_disk1"
    mount "$MAPPER_DEVICE2" "$TMP_mount_disk2"

    if [ ! -d "$TMP_mount_disk2/boot" ]; then
        mkdir -p "$TMP_mount_disk2/boot"
    fi

    mount "$MAPPER_DEVICE1" "$TMP_mount_disk2/boot"
}

# 清理 loop 设备和挂载点
cleanup_image() {
    local LOOP_DEVICE=$1
    local TMP_ROOTFS_DIR=$2
    local TMP_mount_disk1=$3
    local TMP_mount_disk2=$4
    local PATH_PROJECT_DIR=$5

    echo "Cleaning up..."
    cd $PATH_PROJECT_DIR
    unmount_point "$TMP_mount_disk2/boot"
    unmount_point "$TMP_ROOTFS_DIR"
    unmount_point "$TMP_mount_disk1"
    unmount_point "$TMP_mount_disk2"
    if [ -n "$LOOP_DEVICE" ]; then
        if losetup -l >/dev/null 2>&1; then
            while losetup -l | grep -q "$LOOP_DEVICE"; do
                echo "Releasing loop device $LOOP_DEVICE"
                kpartx -dv "$LOOP_DEVICE"
                losetup -d "$LOOP_DEVICE"
                sleep 1
            done
        fi
    fi
}

# ============================================================
# 主函数：从临时目录创建最终的镜像文件
# ============================================================
# 参数说明:
# $1  - PATH_SOURCE:       源代码路径
# $2  - BOARD_MODEL:       开发板型号
# $3  - ENTER_os_ver:      操作系统版本
# $4  - ENTER_rootfs_type: rootfs 类型 (server/desktop)
# $5  - BOOTLOADER_NAME:   bootloader 名称
# $6  - OUTPATH_boot_bin:  boot 二进制文件存放路径
# $7  - LINUX_GIT:         Linux Git 仓库地址
# $8  - LINUX_BRANCH:      Linux 分支名称
# $9  - PATH_PROJECT_DIR:  项目目录路径
# $10 - ENTER_img_file:    烧录镜像文件路径(可选)
# $11 - TMP_ROOTFS_DIR:    已准备好的临时 rootfs 目录
# $12 - TMP_mount_disk1:   分区1挂载点
# $13 - TMP_mount_disk2:   分区2挂载点
create_image_from_staging() {
    local PATH_SOURCE=$1
    local BOARD_MODEL=$2
    local ENTER_os_ver=$3
    local ENTER_rootfs_type=$4
    local BOOTLOADER_NAME=$5
    local OUTPATH_boot_bin=$6
    local LINUX_GIT=$7
    local LINUX_BRANCH=$8
    local PATH_PROJECT_DIR=$9
    local ENTER_img_file=${10}
    local TMP_ROOTFS_DIR=${11}
    local TMP_mount_disk1=${12}
    local TMP_mount_disk2=${13}

    # 设置 trap 以便 Ctrl+C 时能正确清理 loop 设备
    trap 'cleanup_image "$LOOP_DEVICE" "$TMP_ROOTFS_DIR" "$TMP_mount_disk1" "$TMP_mount_disk2" "$PATH_PROJECT_DIR"; exit' SIGINT

    # 计算 rootfs 大小并确定分区尺寸
    local ROOTFS_SIZE=$(du -sm $TMP_ROOTFS_DIR | cut -f1)
    local PART2_SIZE=$(echo "scale=0; ($ROOTFS_SIZE * 1.1)/1" | bc)

    echo "PART1_SIZE=${PART1_SIZE}MB"
    echo "PART2_SIZE=${PART2_SIZE}MB"

    # 确定输出镜像文件名
    cd ${PATH_SOURCE}/wpi-update
    echo -n "$BOARD_MODEL" >/tmp/walnutpi-board_model
    local VERSION_APT=$(echo $(./wpi-update -s | tail -n 1))
    if [ -n "$ENTER_img_file" ]; then
        local OUT_IMG_FILE="${PATH_OUTPUT}/eMMC_burner-$(basename $ENTER_img_file)"
    else
        local OUT_IMG_FILE="${PATH_OUTPUT}/V${VERSION_APT}_$(date +%Y-%m-%d)_${ENTER_rootfs_type}_${BOARD_NAME}_${LINUX_BRANCH}_${ENTER_os_ver}"
    fi
    echo "镜像文件名为$OUT_IMG_FILE"

    local IMG_SIZE=$((PART1_SIZE + PART2_SIZE + 2))
    __create_img_file "$OUT_IMG_FILE" "$IMG_SIZE" "$PART1_SIZE"

    __mount_img_to_dir "$OUT_IMG_FILE" "$TMP_mount_disk1" "$TMP_mount_disk2"

    local BOOT_PARTUUID=$(blkid -s PARTUUID -o value $MAPPER_DEVICE1)
    local ROOTFS_PARTUUID=$(blkid -s PARTUUID -o value $MAPPER_DEVICE2)

    # 写入 bootloader 到镜像
    if [ -f "$OUTPATH_boot_bin/boot.bin" ]; then
        run_status "add $BOOTLOADER_NAME" dd if=$OUTPATH_boot_bin/boot.bin of=$OUT_IMG_FILE bs=1K seek=8 conv=notrunc
    fi
    if [ -f "$OUTPATH_boot_bin/boot_1M.bin" ]; then
        run_status "add $BOOTLOADER_NAME $OUTPATH_boot_bin/boot_1M.bin" dd if=$OUTPATH_boot_bin/boot_1M.bin of=$OUT_IMG_FILE bs=1 seek=1M conv=notrunc
    fi
    if [ -f "$OUTPATH_boot_bin/boot_2M.bin" ]; then
        run_status "add $BOOTLOADER_NAME $OUTPATH_boot_bin/boot_2M.bin" dd if=$OUTPATH_boot_bin/boot_2M.bin of=$OUT_IMG_FILE bs=1 seek=2M conv=notrunc
    fi

    # 使用tar将 TMP_ROOTFS_DIR 路径下的文件全部原封不动地导到TMP_mount_disk2下
    echo "move the rootfs files into the image"
    tar -cf - -C "$TMP_ROOTFS_DIR" . | tar -xf - -C "$TMP_mount_disk2"

    # 写入 PARTUUID
    echo "rootdev=PARTUUID=${ROOTFS_PARTUUID}" | sudo tee -a ${TMP_mount_disk1}/config.txt
    if [ "x$ENTER_img_file" == "x" ]; then
        echo "PARTUUID=${ROOTFS_PARTUUID} / ext4 defaults,acl,noatime,commit=600,errors=remount-ro 0 1" | sudo tee -a ${TMP_mount_disk2}/etc/fstab
    else
        local config_file="${TMP_mount_disk1}/config.txt"
        run_status "config.txt : console_display=disable" sed -i 's/console_display=enable/console_display=disable/g' "$config_file"
        run_status "config.txt : display_bootinfo=disable" sed -i 's/display_bootinfo=enable/display_bootinfo=disable/g' "$config_file"
        echo "PARTUUID=${ROOTFS_PARTUUID} / ext4 ro,defaults,acl,noatime,commit=600,errors=remount-ro 0 1" | sudo tee -a ${TMP_mount_disk2}/etc/fstab
    fi
    echo "PARTUUID=${BOOT_PARTUUID} /boot vfat defaults 0 0" | sudo tee -a ${TMP_mount_disk2}/etc/fstab

    # 生成 initramfs
    local SOURCE_kernel="${PATH_SOURCE}/$(basename "$LINUX_GIT" .git)-$LINUX_BRANCH"
    local kernel_version=$(get_linux_version $SOURCE_kernel)
    echo "generate initramfs"
    run_as_silent chroot $TMP_mount_disk2 /bin/bash -c "DEBIAN_FRONTEND=noninteractive  update-initramfs -uv -k $kernel_version"

    # 清理并重命名输出镜像
    trap - SIGINT EXIT
    cleanup_image "$LOOP_DEVICE" "$TMP_ROOTFS_DIR" "$TMP_mount_disk1" "$TMP_mount_disk2" "$PATH_PROJECT_DIR"

    NEW_IMG_FILE_NAME=$(__get_new_img_file_name "$OUT_IMG_FILE")
    mv $OUT_IMG_FILE $NEW_IMG_FILE_NAME

    echo -e "\noutputfile:\n\n\t\033[32m$(du -h ${NEW_IMG_FILE_NAME})\033[0m\n\n"
}
