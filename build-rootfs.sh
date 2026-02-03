#!/bin/bash
# 获取文件所在路径

PATH_PROJECT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/scripts/common.sh"
source "${SCRIPT_DIR}/scripts/path.sh"
source "${SCRIPT_DIR}/scripts/option.sh"
source "${SCRIPT_DIR}/scripts/menu.sh"
source "${SCRIPT_DIR}/scripts/gen_rootfs.sh"
source "${SCRIPT_DIR}/scripts/pack_rootfs_tar.sh"

# 构建bootloader
# $1 为板级配置文件夹的路径
# $2 为系统版本
# $3 为rootfs类型
main() {
    local ENTER_board_name="${PATH_board}/${1}"
    local ENTER_os_ver=$2
    local ENTER_rootfs_type=$3

    echo "board_name: $ENTER_board_name"
    echo "os_ver: $ENTER_os_ver"
    echo "rootfs_type: $ENTER_rootfs_type"

    source $ENTER_board_name/board.conf
    PATH_OUTPUT_BOARD=${PATH_OUTPUT}/${ENTER_board_name##*/}

    OUTFILE_rootfs_tar="${PATH_OUTPUT_BOARD}/rootfs_${ENTER_os_ver}_${ENTER_rootfs_type}.tar.gz"
    TMP_rootfs_build=${PATH_TMP}/rootfs-build/${BOARD_MODEL}_${ENTER_os_ver}_${ENTER_rootfs_type}
    FILE_base_rootfs=${PATH_TMP}/rootfs-save/${BOARD_MODEL}_${ENTER_os_ver}_${ENTER_rootfs_type}_base_software.tar
    create_dir ${PATH_TMP}/rootfs-build
    create_dir ${PATH_TMP}/rootfs-save

    FILE_apt_base="${ENTER_board_name}/${ENTER_os_ver}/apt-base"
    FILE_apt_del="${ENTER_board_name}/${ENTER_os_ver}/apt-del"
    FILE_apt_desktop="${ENTER_board_name}/${ENTER_os_ver}/apt-desktop"
    FILE_apt_base_board="${ENTER_board_name}/${ENTER_os_ver}/wpi-base"
    FILE_apt_desktop_board="${ENTER_board_name}/${ENTER_os_ver}/wpi-desktop"
    FILE_pip_list="${ENTER_board_name}/${ENTER_os_ver}/pip"
    PLACE_sf_list="${TMP_rootfs_build}/etc/release-apt"

    gen_rootfs $TMP_rootfs_build $FILE_base_rootfs $ENTER_os_ver $FILE_apt_base $FILE_apt_desktop $ENTER_rootfs_type $PLACE_sf_list $PATH_SOURCE $FIRMWARE_GIT $FILE_pip_list $FILE_apt_base_board $FILE_apt_desktop_board $BOARD_MODEL "$MODULES_ENABLE" ${CHIP_ARCH}
    pack_rootfs_tar $TMP_rootfs_build $OUTFILE_rootfs_tar
}

# 如果传入参数个数小于3个,则弹出选择窗口
if [ $# -lt 3 ]; then
    ENTER_board_name=$(basename $(MENU_choose_board $PATH_board))
    ENTER_os_ver=$(MENU_choose_os)
    # 如果ENTER_os_ver的值等于OPT_os_debian12_burn
    if [ $ENTER_os_ver == $OPT_os_debian12_burn ]; then
        ENTER_rootfs_type=$OPT_rootfs_server
    else
        ENTER_rootfs_type=$(MENU_choose_rootfs_type)
    fi
else
    ENTER_board_name=$1
    ENTER_os_ver=$2
    ENTER_rootfs_type=$3
fi

[[ -z ${ENTER_board_name} ]] && exit
[[ -z ${ENTER_os_ver} ]] && exit
[[ -z ${ENTER_rootfs_type} ]] && exit
main $ENTER_board_name $ENTER_os_ver $ENTER_rootfs_type
