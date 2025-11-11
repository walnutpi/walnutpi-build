#!/bin/bash
# 获取文件所在路径

PATH_PROJECT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/scripts/common.sh"
source "${SCRIPT_DIR}/scripts/path.sh"
source "${SCRIPT_DIR}/scripts/option.sh"
source "${SCRIPT_DIR}/scripts/menu.sh"
source "${SCRIPT_DIR}/scripts/pack_all_img.sh"

# 构建bootloader
# $1 为板级配置文件夹的路径
# $2 为系统版本
# $3 为rootfs类型
main() {
    local ENTER_board_name=$1
    local ENTER_os_ver=$2
    local ENTER_rootfs_type=$3

    source $ENTER_board_name/board.conf
    PATH_OUTPUT_BOARD=${PATH_OUTPUT}/${ENTER_board_name##*/}
    source "${SCRIPT_DIR}/scripts/path.sh"
    pack_all_img "$OUTDIR_boot_package" "$OUTDIR_kernel_package" "$OUTFILE_rootfs_tar" "$PATH_SOURCE" "$BOARD_MODEL" "$FILE_apt_del" "$ENTER_os_ver" "$ENTER_rootfs_type" "$IMAGE_FLAG_NO_SCREEN_DISPLAY" "$BOOTLOADER_NAME" "$OUTFILE_boot_bin" "$LINUX_GIT" "$LINUX_BRANCH" "$PATH_PROJECT_DIR" "$NEW_IMG_FILE_NAME"
}

# 如果传入参数个数小于3个,则弹出选择窗口
if [ $# -lt 3 ]; then
    ENTER_board_name=$(MENU_choose_board $PATH_board)
    ENTER_os_ver=$(MENU_choose_os)
    ENTER_rootfs_type=$(MENU_choose_rootfs_type)
else
    ENTER_board_name=$1
    ENTER_os_ver=$2
    ENTER_rootfs_type=$3
fi

[[ -z ${ENTER_board_name} ]] && exit
[[ -z ${ENTER_os_ver} ]] && exit
[[ -z ${ENTER_rootfs_type} ]] && exit
main $ENTER_board_name $ENTER_os_ver $ENTER_rootfs_type
