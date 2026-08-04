#!/bin/bash
# scripts/image/build.sh — 镜像组装入口

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -z "${ROOT_DIR}" ]; then
    ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
fi
if [ -z "${PATH_PROJECT_DIR}" ]; then
    PATH_PROJECT_DIR="${ROOT_DIR}"
fi

source "${ROOT_DIR}/scripts/__common.sh"
source "${ROOT_DIR}/scripts/__path.sh"
source "${ROOT_DIR}/scripts/__option.sh"
source "${ROOT_DIR}/scripts/__menu.sh"

source "${SCRIPT_DIR}/__make_prepare.sh"
source "${SCRIPT_DIR}/__make_image.sh"

readonly IMAGE_FLAG_NO_SCREEN_DISPLAY=$OPT_NO
readonly IMAGE_FLAG_DISK_RAED_ONLY=$OPT_NO
readonly PART1_SIZE=150

# $1 - OUTDIR_boot_package: boot包输出目录
# $2 - OUTDIR_kernel_package: kernel包输出目录
# $3 - OUTFILE_rootfs_tar: rootfs tar文件路径
# $4 - PATH_SOURCE: 源代码路径
# $5 - BOARD_MODEL: 开发板型号
# $6 - FILE_apt_del: 需要删除的apt包列表文件
# $7 - ENTER_os_ver: 操作系统版本选择
# $8 - ENTER_rootfs_type: rootfs类型
# $9 - IMAGE_FLAG_NO_SCREEN_DISPLAY: 无屏幕显示标志
# $10 - BOOTLOADER_NAME: bootloader名称
# $11 - OUTPATH_boot_bin: 输出的boot二进制文件的存放路径
# $12 - LINUX_GIT: Linux Git仓库地址
# $13 - LINUX_BRANCH: Linux分支名称
# $14 - PATH_PROJECT_DIR: 项目目录路径
# $15 - ENTER_img_file: 烧录镜像文件路径（可选）
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
    local OUTPATH_boot_bin=${11}
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
    echo "OUTPATH_boot_bin: $OUTPATH_boot_bin"
    echo "LINUX_GIT: $LINUX_GIT"
    echo "LINUX_BRANCH: $LINUX_BRANCH"
    echo "PATH_PROJECT_DIR: $PATH_PROJECT_DIR"
    echo "ENTER_img_file: $ENTER_img_file"
    echo "========================================================="

    # 定义临时目录路径
    local TMP_IMG_BOOT="${PATH_TMP}/IMG/BootDisk-${BOARD_NAME}-${ENTER_os_ver}_${ENTER_rootfs_type}"
    local TMP_ROOTFS_DIR="${PATH_TMP}/IMG/Rootfs-${BOARD_NAME}-${ENTER_os_ver}_${ENTER_rootfs_type}"
    local TMP_mount_disk1="${PATH_TMP}/MountPoint/PART1-${BOARD_NAME}-${ENTER_os_ver}_${ENTER_rootfs_type}"
    local TMP_mount_disk2="${PATH_TMP}/MountPoint/PART2-${BOARD_NAME}-${ENTER_os_ver}_${ENTER_rootfs_type}"

    create_dir "${PATH_TMP}/IMG"
    create_dir "${PATH_TMP}/MountPoint"

    # 阶段1：将 boot、kernel、rootfs 三个组件准备到临时目录中
    prepare_staging \
        "$OUTDIR_boot_package" "$OUTDIR_kernel_package" "$OUTFILE_rootfs_tar" \
        "$FILE_apt_del" "$ENTER_os_ver" "$ENTER_rootfs_type" "$ENTER_img_file" \
        "$TMP_ROOTFS_DIR" "$TMP_IMG_BOOT" "$TMP_mount_disk1" "$TMP_mount_disk2"

    # 阶段2：从临时目录申请 loop 设备，创建最终镜像文件
    create_image_from_staging \
        "$PATH_SOURCE" "$BOARD_MODEL" "$ENTER_os_ver" "$ENTER_rootfs_type" \
        "$BOOTLOADER_NAME" "$OUTPATH_boot_bin" "$LINUX_GIT" "$LINUX_BRANCH" \
        "$PATH_PROJECT_DIR" "$ENTER_img_file" \
        "$TMP_ROOTFS_DIR" "$TMP_mount_disk1" "$TMP_mount_disk2"
}

# $1 为板级配置文件夹的路径
# $2 为系统版本
# $3 为rootfs类型
# $4 为镜像文件路径
main() {
    local ENTER_board_name="${PATH_board}/${1}"
    local ENTER_os_ver=$2
    local ENTER_rootfs_type=$3
    local ENTER_img_file=$4

    source $ENTER_board_name/board.conf

    local OUTDIR_boot_package=$(_path_outdir_boot "$1")
    local OUTDIR_kernel_package=$(_path_outdir_kernel "$1")
    local OUTFILE_rootfs_tar=$(_path_outfile_rootfs_tar "$1" "$ENTER_os_ver" "$ENTER_rootfs_type")
    local FILE_apt_del=$(_path_file_apt_del "$1" "$ENTER_os_ver")

    pack_all_img \
        "$OUTDIR_boot_package" "$OUTDIR_kernel_package" "$OUTFILE_rootfs_tar" \
        "$PATH_SOURCE" "$BOARD_MODEL" "$FILE_apt_del" "$ENTER_os_ver" "$ENTER_rootfs_type" \
        "$IMAGE_FLAG_NO_SCREEN_DISPLAY" "$BOOTLOADER_NAME" "$OUTDIR_boot_package" \
        "$LINUX_GIT" "$LINUX_BRANCH" "$PATH_PROJECT_DIR" "$ENTER_img_file"
}

# 如果传入参数个数小于3个,则弹出选择窗口
if [ $# -lt 3 ]; then
    ENTER_board_name=$(basename $(MENU_choose_board $PATH_board))
    [[ -z ${ENTER_board_name} ]] && exit
    ENTER_os_ver=$(MENU_choose_os "${PATH_board}/$ENTER_board_name")
    if [ $ENTER_os_ver == $OPT_os_debian12_burn ]; then
        ENTER_rootfs_type=$OPT_rootfs_server
        ENTER_img_file="$(MENU_choose_img_file)"
        [[ -z ${ENTER_board_name} ]] && exit
        ENTER_img_file="$PATH_OUTPUT/$ENTER_img_file"
    else
        ENTER_rootfs_type=$(MENU_choose_rootfs_type)
    fi
else
    ENTER_board_name=$1
    ENTER_os_ver=$2
    ENTER_rootfs_type=$3
    ENTER_img_file=$4
fi

[[ -z ${ENTER_board_name} ]] && exit
[[ -z ${ENTER_os_ver} ]] && exit
[[ -z ${ENTER_rootfs_type} ]] && exit
main $ENTER_board_name $ENTER_os_ver $ENTER_rootfs_type $ENTER_img_file
