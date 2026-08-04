#!/bin/bash
# scripts/image/__make_prepare.sh
# 阶段1：将 boot、kernel、rootfs 三个组件准备到临时目录中
#
# 职责：
#   1. 检查所有输入资源是否存在
#   2. 创建临时目录结构
#   3. 创建 boot 分区镜像并挂载
#   4. 解压 rootfs、安装 boot/kernel 的 deb 包
#   5. 执行 chroot 后处理（set-lcd、apt remove、gdm3→lightdm）

# 检查所需文件是不是都生成了
check_resource() {
    local OUTDIR_boot_package=$1
    local OUTDIR_kernel_package=$2
    local OUTFILE_rootfs_tar=$3

    if [ ! -d "$OUTDIR_boot_package" ]; then
        echo "$OUTDIR_boot_package no exist"
        exit 1
    fi
    if [ ! -d "$OUTDIR_kernel_package" ]; then
        echo "$OUTDIR_kernel_package no exist"
        exit 1
    fi
    if [ ! -f "$OUTFILE_rootfs_tar" ]; then
        echo "$OUTFILE_rootfs_tar no exist"
        exit 1
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

# ============================================================
# 主函数：将 boot、kernel、rootfs 三个组件准备到临时目录中
# ============================================================
# 参数说明:
# $1  - OUTDIR_boot_package:   boot 包输出目录
# $2  - OUTDIR_kernel_package: kernel 包输出目录
# $3  - OUTFILE_rootfs_tar:    rootfs tar 文件路径
# $4  - FILE_apt_del:          需要删除的apt包列表文件
# $5  - ENTER_os_ver:          操作系统版本
# $6  - ENTER_rootfs_type:     rootfs 类型 (server/desktop)
# $7  - ENTER_img_file:        烧录镜像文件路径(可选)
# $8  - TMP_ROOTFS_DIR:        临时 rootfs 目录
# $9  - TMP_IMG_BOOT:          临时 boot 镜像文件
# $10 - TMP_mount_disk1:       分区1挂载点
# $11 - TMP_mount_disk2:       分区2挂载点
prepare_staging() {
    local OUTDIR_boot_package=$1
    local OUTDIR_kernel_package=$2
    local OUTFILE_rootfs_tar=$3
    local FILE_apt_del=$4
    local ENTER_os_ver=$5
    local ENTER_rootfs_type=$6
    local ENTER_img_file=$7
    local TMP_ROOTFS_DIR=$8
    local TMP_IMG_BOOT=$9
    local TMP_mount_disk1=${10}
    local TMP_mount_disk2=${11}

    check_resource "$OUTDIR_boot_package" "$OUTDIR_kernel_package" "$OUTFILE_rootfs_tar"

    __create_tmp_dir "$TMP_ROOTFS_DIR" "$TMP_mount_disk1" "$TMP_mount_disk2"
    __create_tmp_img_boot "$TMP_IMG_BOOT" "$PART1_SIZE"

    # 挂载boot img到rootfs文件夹中
    run_status "mount part1 file" mount -o loop $TMP_IMG_BOOT ${TMP_ROOTFS_DIR}/boot

    # 将 boot kernel rootfs 都输出到临时目录中
    __add_file_to_tmp_rootfs_dir "$OUTFILE_rootfs_tar" "$OUTDIR_boot_package" "$OUTDIR_kernel_package" "$TMP_ROOTFS_DIR" "$ENTER_img_file"

    # 为了让set-lcd统一管理显示屏，所以需要构建时运行一次
    chroot ${TMP_ROOTFS_DIR} /bin/bash -c "set-lcd"

    # 为了减小体积，可以删除掉在构建完成后就不需要了的包
    if [ -f ${FILE_apt_del} ]; then
        mapfile -t packages < <(grep -vE '^#|^$' ${FILE_apt_del})
        local total=${#packages[@]}
        for ((i = 0; i < ${total}; i++)); do
            local package=${packages[$i]}
            run_status "apt remove [$((i + 1))/${total}] : $package " chroot $TMP_ROOTFS_DIR /bin/bash -c "DEBIAN_FRONTEND=noninteractive  apt-get -o Dpkg::Options::='--force-overwrite' remove -y ${package}"
        done
        run_status "apt autoremove" chroot $TMP_ROOTFS_DIR /bin/bash -c "DEBIAN_FRONTEND=noninteractive  apt autoremove -y"
    fi

    # 如果是ubuntu24，则禁用gdm3改为lightdm
    if [ "$ENTER_os_ver" == "$OPT_os_ubuntu24" ]; then
        if [[ "${ENTER_rootfs_type}" == "desktop" ]]; then
            echo "切换lightdm为默认桌面环境"
            run_status "remove gdm3 " chroot ${TMP_ROOTFS_DIR} /bin/bash -c "DEBIAN_FRONTEND=noninteractive  apt-get -o Dpkg::Options::='--force-overwrite' remove -y gdm3"
            chroot $TMP_ROOTFS_DIR /bin/bash -c "dpkg-reconfigure lightdm"
        fi
    fi

    echo "prepare_staging completed. TMP_ROOTFS_DIR=$TMP_ROOTFS_DIR"
}
