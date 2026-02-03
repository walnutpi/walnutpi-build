#!/bin/bash
# 获取文件所在路径

PATH_PROJECT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/scripts/common.sh"
source "${SCRIPT_DIR}/scripts/path.sh"
source "${SCRIPT_DIR}/scripts/option.sh"
source "${SCRIPT_DIR}/scripts/menu.sh"
source "${SCRIPT_DIR}/scripts/pack_all_img.sh"

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
    PATH_OUTPUT_BOARD=${PATH_OUTPUT}/${ENTER_board_name##*/}
    source "${SCRIPT_DIR}/scripts/path.sh"
    pack_all_img "$OUTDIR_boot_package" "$OUTDIR_kernel_package" "$OUTFILE_rootfs_tar" "$PATH_SOURCE" "$BOARD_MODEL" "$FILE_apt_del" "$ENTER_os_ver" "$ENTER_rootfs_type" "$IMAGE_FLAG_NO_SCREEN_DISPLAY" "$BOOTLOADER_NAME" "$OUTFILE_boot_bin" "$LINUX_GIT" "$LINUX_BRANCH" "$PATH_PROJECT_DIR" "$ENTER_img_file"
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
