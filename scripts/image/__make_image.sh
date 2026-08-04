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

    # 原子操作：一次性查找空闲 loop 设备并绑定镜像文件（消除 TOCTOU 竞态）
    for ((i = 0; i < MAX_RETRIES; i++)); do
        LOOP_DEVICE=$(losetup --find --show "$OUT_IMG_FILE" 2>/dev/null)
        local ret=$?

        if [ $ret -eq 0 ] && [ -n "$LOOP_DEVICE" ] && [ -b "$LOOP_DEVICE" ]; then
            # 验证：确认 loop 设备确实指向我们的镜像文件
            local actual_file=$(losetup -ln -O BACK-FILE "$LOOP_DEVICE" 2>/dev/null)
            if [ "$actual_file" = "$OUT_IMG_FILE" ]; then
                echo "成功绑定 loop 设备: $LOOP_DEVICE -> $OUT_IMG_FILE"
                break
            else
                echo "警告: loop 设备验证失败，期望 $OUT_IMG_FILE，实际 $actual_file"
                losetup -d "$LOOP_DEVICE" 2>/dev/null || true
                LOOP_DEVICE=""
            fi
        fi

        echo "获取 loop 设备失败，重试 ($((i + 1))/$MAX_RETRIES)..."
        sleep 2
    done

    if [ -z "$LOOP_DEVICE" ]; then
        echo "错误: 无法获取可用 loop 设备"
        exit 1
    fi

    # 3. 使用 kpartx 扫描分区表（比 losetup -P 更兼容，-P 在某些内核不生效）
    kpartx -av "$LOOP_DEVICE"
    local LOOP_BASENAME=$(basename "$LOOP_DEVICE")
    MAPPER_DEVICE1="/dev/mapper/${LOOP_BASENAME}p1"
    MAPPER_DEVICE2="/dev/mapper/${LOOP_BASENAME}p2"

    # 等待分区设备出现
    for i in {1..10}; do
        if [ -b "$MAPPER_DEVICE1" ] && [ -b "$MAPPER_DEVICE2" ]; then
            break
        fi
        echo "等待分区设备就绪... ($i/10)"
        sleep 0.5
    done

    if [ ! -b "$MAPPER_DEVICE1" ] || [ ! -b "$MAPPER_DEVICE2" ]; then
        echo "错误: 分区设备未出现 $MAPPER_DEVICE1 $MAPPER_DEVICE2"
        kpartx -dv "$LOOP_DEVICE" 2>/dev/null || true
        losetup -d "$LOOP_DEVICE"
        exit 1
    fi

    echo "分区设备就绪: $MAPPER_DEVICE1 $MAPPER_DEVICE2"

    # 格式化并挂载
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

    # 1. 卸载主镜像的分区挂载
    unmount_point "$TMP_mount_disk2/boot"
    unmount_point "$TMP_mount_disk1"
    unmount_point "$TMP_mount_disk2"

    # 2. 卸载 boot 镜像（阶段1 prepare_staging 挂载的），并释放其 loop 设备
    if [ -n "$TMP_ROOTFS_DIR" ] && [ "$TMP_ROOTFS_DIR" != "/" ]; then
        unmount_point "$TMP_ROOTFS_DIR/boot"

        # 查找关联 BootDisk 镜像的 loop 设备并释放
        while IFS= read -r ld_dev; do
            [ -z "$ld_dev" ] && continue
            # 统一格式：去掉可能的前缀 /dev/ 后重新拼接
            ld_dev="/dev/${ld_dev#/dev/}"
            echo "Releasing boot image loop device: $ld_dev"
            losetup -d "$ld_dev" 2>/dev/null || true
        done < <(losetup -ln -O NAME,BACK-FILE 2>/dev/null \
            | grep "BootDisk-" \
            | awk '{print $1}')
    fi

    # 3. 释放主镜像的 loop 设备（带最大重试次数，避免死循环）
    if [ -n "$LOOP_DEVICE" ]; then
        local max_release_retries=10
        for ((i = 0; i < max_release_retries; i++)); do
            if ! losetup -l 2>/dev/null | grep -q "$LOOP_DEVICE"; then
                echo "Loop device $LOOP_DEVICE already released"
                break
            fi
            echo "Releasing loop device $LOOP_DEVICE (attempt $((i + 1))/$max_release_retries)"
            kpartx -dv "$LOOP_DEVICE" 2>/dev/null || true
            losetup -d "$LOOP_DEVICE" 2>/dev/null && break
            echo "  -> release failed, retrying in 1s..."
            sleep 1
        done
        if losetup -l 2>/dev/null | grep -q "$LOOP_DEVICE"; then
            echo "WARNING: Failed to release loop device $LOOP_DEVICE after $max_release_retries attempts"
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

    # 设置 trap 以便异常退出时能正确清理 loop 设备
    trap 'cleanup_image "$LOOP_DEVICE" "$TMP_ROOTFS_DIR" "$TMP_mount_disk1" "$TMP_mount_disk2" "$PATH_PROJECT_DIR"; exit' SIGINT SIGTERM EXIT

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
    trap - SIGINT SIGTERM EXIT
    cleanup_image "$LOOP_DEVICE" "$TMP_ROOTFS_DIR" "$TMP_mount_disk1" "$TMP_mount_disk2" "$PATH_PROJECT_DIR"

    NEW_IMG_FILE_NAME=$(__get_new_img_file_name "$OUT_IMG_FILE")
    mv $OUT_IMG_FILE $NEW_IMG_FILE_NAME

    echo -e "\noutputfile:\n\n\t\033[32m$(du -h ${NEW_IMG_FILE_NAME})\033[0m\n\n"
}
