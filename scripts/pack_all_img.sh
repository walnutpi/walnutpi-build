#!/bin/bash

IMAGE_FLAG_NO_SCREEN_DISPLAY=$OPT_NO
IMAGE_FLAG_DISK_RAED_ONLY=$OPT_NO

PART1_SIZE=150
PART2_SIZE=0

# 检查所需文件是不是都生成了
check_resource() {
    if [ ! -d "$OUTDIR_boot_package" ]; then
        echo $OUTDIR_boot_package "no exist"
        exit
    fi
    if [ ! -d "$OUTDIR_kernel_package" ]; then
        echo $OUTDIR_kernel_package "no exist"
        exit
    fi
    if [ ! -f "$OUTFILE_rootfs_tar" ]; then
        echo $OUTFILE_rootfs_tar "no exist"
        exit
    fi
}

__create_tmp_dir() {
    local TMP_ROOTFS_DIR=$1
    local TMP_mount_disk1=$2
    local TMP_mount_disk2=$3

    # 使用安全函数删除临时目录
    if [ -n "$TMP_ROOTFS_DIR" ] && [ "$TMP_ROOTFS_DIR" != "/" ]; then
        if [ -d "$TMP_ROOTFS_DIR/boot" ]; then
            umount "$TMP_ROOTFS_DIR/boot" 2>/dev/null || true
            safe_remove_tmp_dir "$TMP_ROOTFS_DIR/boot"
        fi
        safe_remove_tmp_dir "$TMP_ROOTFS_DIR"
    else
        echo "警告: TMP_ROOTFS_DIR变量未正确设置，跳过清理操作"
        echo "TMP_ROOTFS_DIR = $TMP_ROOTFS_DIR"
    fi

    if [ -n "$TMP_mount_disk1" ] && [ "$TMP_mount_disk1" != "/" ]; then
        safe_remove_tmp_dir "$TMP_mount_disk1"
    else
        echo "警告: TMP_mount_disk1变量未正确设置，跳过清理操作"
        echo "TMP_mount_disk1 = $TMP_mount_disk1"
    fi

    if [ -n "$TMP_mount_disk2" ] && [ "$TMP_mount_disk2" != "/" ]; then
        safe_remove_tmp_dir "$TMP_mount_disk2"
    else
        echo "警告: TMP_mount_disk2变量未正确设置，跳过清理操作"
        echo "TMP_mount_disk2 = $TMP_mount_disk2"
    fi

    mkdir -p $TMP_ROOTFS_DIR
    mkdir -p $TMP_ROOTFS_DIR/boot
    mkdir -p $TMP_mount_disk1
    mkdir -p $TMP_mount_disk2
}

__create_tmp_img_boot() {
    local TMP_IMG_BOOT=$1
    local PART1_SIZE=$2

    if [ -f "$TMP_IMG_BOOT" ]; then
        rm ${TMP_IMG_BOOT}
    fi
    run_status "create part1 file" dd if=/dev/zero of=$TMP_IMG_BOOT bs=1M count=$PART1_SIZE
    run_status "format part1 file" mkfs.fat -F 32 -n "boot" $TMP_IMG_BOOT
}

__add_file_to_tmp_rootfs_dir() {
    local OUTFILE_rootfs_tar=$1
    local OUTDIR_boot_package=$2
    local OUTDIR_kernel_package=$3
    local TMP_ROOTFS_DIR=$4
    local ENTER_img_file=$5

    run_status "add rootfs" tar xf $OUTFILE_rootfs_tar -C $TMP_ROOTFS_DIR -I 'xz -T0'

    # 如果ENTER_img_file不为空
    if [ -n "$ENTER_img_file" ]; then
        mkdir -p ${TMP_ROOTFS_DIR}/opt/burn
        cp ${ENTER_img_file} ${TMP_ROOTFS_DIR}/opt/burn/
        run_status "copy $(basename $ENTER_img_file) to ${TMP_ROOTFS_DIR}/opt/burn/" cp "$ENTER_img_file" "${TMP_ROOTFS_DIR}/opt/burn/"
    fi

    echo "TMP_ROOTFS_DIR = ${TMP_ROOTFS_DIR}"

    cp /usr/bin/qemu-aarch64-static ${TMP_ROOTFS_DIR}/usr/bin/
    chmod +x ${TMP_ROOTFS_DIR}/usr/bin/qemu-aarch64-static

    # 安装boot相关的deb包
    cp ${OUTDIR_boot_package}/*.deb ${TMP_ROOTFS_DIR}/opt/
    cd ${TMP_ROOTFS_DIR}/opt/
    local deb_packages=(*.deb)
    local total=${#deb_packages[@]}
    for ((i = 0; i < $total; i++)); do
        local deb_package=${deb_packages[$i]}
        run_status "boot package [$((i + 1))/${total}] : ${deb_package} " chroot ${TMP_ROOTFS_DIR} /bin/bash -c "dpkg -i /opt/${deb_package}"
        rm ${TMP_ROOTFS_DIR}/opt/${deb_package}
    done

    # 安装kernel产生的的deb包，先安装生成时间早的
    cd ${OUTDIR_kernel_package}/
    local deb_packages=($(ls -t *.deb | tac))
    cp ${OUTDIR_kernel_package}/*.deb ${TMP_ROOTFS_DIR}/opt/
    cd ${TMP_ROOTFS_DIR}/opt/
    total=${#deb_packages[@]}
    for ((i = 0; i < $total; i++)); do
        local deb_package=${deb_packages[$i]}
        run_status "kernel package [$((i + 1))/${total}] : ${deb_package} " chroot ${TMP_ROOTFS_DIR} /bin/bash -c "dpkg -i /opt/${deb_package}"
        rm ${TMP_ROOTFS_DIR}/opt/${deb_package}
    done
}
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
    parted $OUT_IMG_FILE --script mkpart primary fat32 1M $((PART1_SIZE + 1))M
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
# 参数说明:
# $1  - OUTDIR_boot_package: boot包输出目录
# $2  - OUTDIR_kernel_package: kernel包输出目录
# $3  - OUTFILE_rootfs_tar: rootfs tar文件路径
# $4  - PATH_SOURCE: 源代码路径
# $5  - BOARD_MODEL: 开发板型号
# $6  - FILE_apt_del: 需要删除的apt包列表文件
# $7  - ENTER_os_ver: 操作系统版本选择
# $8  - ENTER_rootfs_type: rootfs类型
# $9  - IMAGE_FLAG_NO_SCREEN_DISPLAY: 无屏幕显示标志
# $10 - BOOTLOADER_NAME: bootloader名称
# $11 - OUTFILE_boot_bin: boot二进制文件路径
# $12 - LINUX_GIT: Linux Git仓库地址
# $13 - LINUX_BRANCH: Linux分支名称
# $14 - PATH_PROJECT_DIR: 项目目录路径
# $15 - NEW_IMG_FILE_NAME: 新镜像文件名（可选）

pack_all_img() {
    local OUTDIR_boot_package=$1
    local OUTDIR_kernel_package=$2
    local OUTFILE_rootfs_tar=$3
    local PATH_SOURCE=$4
    local BOARD_MODEL=$5
    local FILE_apt_del=$6
    local ENTER_os_ver=$7
    local ENTER_rootfs_type=$8
    local IMAGE_FLAG_NO_SCREEN_DISPLAY=$9
    local BOOTLOADER_NAME=${10}
    local OUTFILE_boot_bin=${11}
    local LINUX_GIT=${12}
    local LINUX_BRANCH=${13}
    local PATH_PROJECT_DIR=${14}
    local ENTER_img_file="${15}"

    # 输出所有参数
    echo "=================== pack_all_img 参数值 ==================="
    echo "OUTDIR_boot_package: $OUTDIR_boot_package"
    echo "OUTDIR_kernel_package: $OUTDIR_kernel_package"
    echo "OUTFILE_rootfs_tar: $OUTFILE_rootfs_tar"
    echo "PATH_SOURCE: $PATH_SOURCE"
    echo "BOARD_MODEL: $BOARD_MODEL"
    echo "FILE_apt_del: $FILE_apt_del"
    echo "ENTER_os_ver: $ENTER_os_ver"
    echo "ENTER_rootfs_type: $ENTER_rootfs_type"
    echo "IMAGE_FLAG_NO_SCREEN_DISPLAY: $IMAGE_FLAG_NO_SCREEN_DISPLAY"
    echo "BOOTLOADER_NAME: $BOOTLOADER_NAME"
    echo "OUTFILE_boot_bin: $OUTFILE_boot_bin"
    echo "LINUX_GIT: $LINUX_GIT"
    echo "LINUX_BRANCH: $LINUX_BRANCH"
    echo "PATH_PROJECT_DIR: $PATH_PROJECT_DIR"
    echo "ENTER_img_file: $ENTER_img_file"
    echo "========================================================="

    local TMP_IMG_BOOT="${PATH_TMP}/IMG/BootDisk-${BOARD_NAME}-${ENTER_os_ver}_${ENTER_rootfs_type}"
    local TMP_ROOTFS_DIR="${PATH_TMP}/IMG/Rootfs-${BOARD_NAME}-${ENTER_os_ver}_${ENTER_rootfs_type}"
    local TMP_mount_disk1="${PATH_TMP}/MountPoint/PART1-${BOARD_NAME}-${ENTER_os_ver}_${ENTER_rootfs_type}"
    local TMP_mount_disk2="${PATH_TMP}/MountPoint/PART2-${BOARD_NAME}-${ENTER_os_ver}_${ENTER_rootfs_type}"

    create_dir "${PATH_TMP}/IMG"
    create_dir "${PATH_TMP}/MountPoint"

    cleanup() {
        local LOOP_DEVICE=$1
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

    trap 'cleanup "$LOOP_DEVICE"; exit' SIGINT
    check_resource

    __create_tmp_dir "$TMP_ROOTFS_DIR" "$TMP_mount_disk1" "$TMP_mount_disk2"
    __create_tmp_img_boot "$TMP_IMG_BOOT" "$PART1_SIZE"
    # 挂载boot img到rootfs文件夹中
    run_status "mount part1 file" mount -o loop $TMP_IMG_BOOT ${TMP_ROOTFS_DIR}/boot
    # 将boot kernel rootfs都输出到临时目录中
    __add_file_to_tmp_rootfs_dir "$OUTFILE_rootfs_tar" "$OUTDIR_boot_package" "$OUTDIR_kernel_package" "$TMP_ROOTFS_DIR" "$ENTER_img_file"

    # 为了让set-lcd统一管理显示屏，所以需要构建时运行一次
    run_status "run set-lcd hdmi install " chroot ${TMP_ROOTFS_DIR} /bin/bash -c "set-lcd hdmi install"

    # 为了减小体积，可以删除掉在构建完成后就不需要了的包
    if [ -f ${FILE_apt_del} ]; then
        mapfile -t packages < <(grep -vE '^#|^$' ${FILE_apt_del})
        total=${#packages[@]}
        for ((i = 0; i < ${total}; i++)); do
            local package=${packages[$i]}
            run_status "apt remove [$((i + 1))/${total}] : $package " chroot $TMP_ROOTFS_DIR /bin/bash -c "DEBIAN_FRONTEND=noninteractive  apt-get -o Dpkg::Options::='--force-overwrite' remove -y ${package}"
        done
    fi

    # 如果是ubuntu24，则禁用gdm3改为lightdm
    if [ "$ENTER_os_ver" == "$OPT_os_ubuntu24" ]; then
        if [[ "${ENTER_rootfs_type}" == "desktop" ]]; then
            echo "切换lightdm为默认桌面环境"
            run_status "remove gdm3 " chroot ${TMP_ROOTFS_DIR} /bin/bash -c "DEBIAN_FRONTEND=noninteractive  apt-get -o Dpkg::Options::='--force-overwrite' remove -y gdm3"
            chroot $TMP_ROOTFS_DIR /bin/bash -c "dpkg-reconfigure lightdm"
        fi
    fi

    local ROOTFS_SIZE=$(du -sm $TMP_ROOTFS_DIR | cut -f1)
    local PART2_SIZE=$(echo "scale=0; ($ROOTFS_SIZE * 1.024 + 100)/1" | bc)

    echo "PART1_SIZE=${PART1_SIZE}MB"
    echo "PART2_SIZE=${PART2_SIZE}MB"

    cd ${PATH_SOURCE}/wpi-update
    echo -n "$BOARD_MODEL" >/tmp/walnutpi-board_model
    local VERSION_APT=$(echo $(./wpi-update -s | tail -n 1))
    if [ -n "$ENTER_img_file" ]; then
        local OUT_IMG_FILE="${PATH_OUTPUT}/eMMC_burner-$(basename $ENTER_img_file)"
    else
        local OUT_IMG_FILE="${PATH_OUTPUT}/V${VERSION_APT}_$(date +%m-%d)_${ENTER_rootfs_type}_${BOARD_NAME}_${LINUX_BRANCH}_${ENTER_os_ver}"
    fi
    echo "镜像文件名为$OUT_IMG_FILE"
    local IMG_SIZE=$((PART1_SIZE + PART2_SIZE + 2))
    __create_img_file "$OUT_IMG_FILE" "$IMG_SIZE" "$PART1_SIZE"

    __mount_img_to_dir() {
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
                # 清除缓存

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
    __mount_img_to_dir

    local BOOT_PARTUUID=$(blkid -s PARTUUID -o value $MAPPER_DEVICE1)
    local ROOTFS_PARTUUID=$(blkid -s PARTUUID -o value $MAPPER_DEVICE2)

    # 导入文件
    run_status "add $BOOTLOADER_NAME" dd if=$OUTFILE_boot_bin of=$OUT_IMG_FILE bs=1K seek=8 conv=notrunc
    # 使用tar将 TMP_ROOTFS_DIR 路径下的文件全部原封不动的导到TMP_mount_disk2下
    echo "move the rootfs files into the image"
    tar -cf - -C "$TMP_ROOTFS_DIR" . | tar -xf - -C "$TMP_mount_disk2"
    # run_status "add rootfs" tar -cf - -C "$TMP_ROOTFS_DIR" . | tar -xf - -C "$TMP_mount_disk2"

    # 写入uuid
    echo "rootdev=PARTUUID=${ROOTFS_PARTUUID}" | sudo tee -a ${TMP_mount_disk1}/config.txt
    if [ $IMAGE_FLAG_NO_SCREEN_DISPLAY == $OPT_NO ]; then
        echo "PARTUUID=${ROOTFS_PARTUUID} / ext4 defaults,acl,noatime,commit=600,errors=remount-ro 0 1" | sudo tee -a ${TMP_mount_disk2}/etc/fstab
    else
        echo "PARTUUID=${ROOTFS_PARTUUID} / ext4 ro,defaults,acl,noatime,commit=600,errors=remount-ro 0 1" | sudo tee -a ${TMP_mount_disk2}/etc/fstab
    fi
    echo "PARTUUID=${BOOT_PARTUUID} /boot vfat defaults 0 0" | sudo tee -a ${TMP_mount_disk2}/etc/fstab

    if [ $IMAGE_FLAG_NO_SCREEN_DISPLAY != $OPT_NO ]; then
        local config_file="${TMP_mount_disk1}/config.txt"
        run_status "config.txt : console_display=disable" sed -i 's/console_display=enable/console_display=disable/g' "$config_file"
        run_status "config.txt : display_bootinfo=disable" sed -i 's/display_bootinfo=enable/display_bootinfo=disable/g' "$config_file"
    fi

    local SOURCE_kernel="${PATH_SOURCE}/$(basename "$LINUX_GIT" .git)-$LINUX_BRANCH"
    local kernel_version=$(get_linux_version $SOURCE_kernel)
    # run_status_no_retry "generate initramfs" chroot $TMP_mount_disk2 /bin/bash -c "DEBIAN_FRONTEND=noninteractive  update-initramfs -uv -k $kernel_version"
    echo ""generate initramfs""
    run_as_silent chroot $TMP_mount_disk2 /bin/bash -c "DEBIAN_FRONTEND=noninteractive  update-initramfs -uv -k $kernel_version"

    trap - SIGINT EXIT
    cleanup "$LOOP_DEVICE"

    NEW_IMG_FILE_NAME=$(__get_new_img_file_name "$OUT_IMG_FILE")
    mv $OUT_IMG_FILE $NEW_IMG_FILE_NAME

    echo -e "\noutputfile:\n\n\t\033[32m$(du -h ${NEW_IMG_FILE_NAME})\033[0m\n\n"
}
