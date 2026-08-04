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

source "${SCRIPT_DIR}/__make.sh"

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
