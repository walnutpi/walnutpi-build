#!/bin/bash
# 获取文件所在路径

PATH_PROJECT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/scripts/common.sh"
source "${SCRIPT_DIR}/scripts/path.sh"
source "${SCRIPT_DIR}/scripts/option.sh"
source "${SCRIPT_DIR}/scripts/menu.sh"
source "${SCRIPT_DIR}/scripts/compile_uboot.sh"
source "${SCRIPT_DIR}/scripts/compile_Syterkit.sh"
source "${SCRIPT_DIR}/scripts/pack_boot_deb.sh"

# 构建bootloader
# $1 为板级配置文件夹的路径
build_bootloader() {
    local ENTER_board_name=${PATH_board}/${1}
    source $ENTER_board_name/board.conf
    PATH_OUTPUT_BOARD=${PATH_OUTPUT}/${ENTER_board_name##*/}
    create_dir $PATH_OUTPUT_BOARD
    if [ ! -z $TOOLCHAIN_DOWN_URL ]; then

        USE_CROSS_COMPILE="${PATH_TOOLCHAIN}/${TOOLCHAIN_FILE_NAME}/bin/${CROSS_COMPILE}"
        if [ ! -f "${USE_CROSS_COMPILE}gcc" ]; then
            wget -P ${PATH_TOOLCHAIN} $TOOLCHAIN_DOWN_URL
            run_status "unzip toolchain" tar -xvf ${PATH_TOOLCHAIN}/${TOOLCHAIN_FILE_NAME}.tar.xz -C $PATH_TOOLCHAIN
        fi
    else
        if [ ! -f /usr/bin/${CROSS_COMPILE}gcc ]; then
            apt install ${TOOLCHAIN_NAME_IN_APT}
        fi
        USE_CROSS_COMPILE="${CROSS_COMPILE}"

    fi

    if [ -d $OUTDIR_boot_package ]; then
        rm -r $OUTDIR_boot_package
    fi
    create_dir $OUTDIR_boot_package

    OUTDIR_boot_package=${PATH_OUTPUT_BOARD}/boot
    OUTFILE_boot_bin=${OUTDIR_boot_package}/boot.bin
    PATH_save_boot_files="${ENTER_board_name}/boot"

    if [ -n "$UBOOT_CONFIG" ]; then
        if [ -n "$ATF_GIT" ]; then
            compile_atf "$PATH_SOURCE" "$ATF_GIT" "$ATF_BRANCH" "$ATF_PLAT" "$USE_CROSS_COMPILE"
        fi
        compile_uboot "$PATH_SOURCE" "$UBOOT_GIT" "$UBOOT_BRANCH" "$UBOOT_CONFIG" \
            "$USE_CROSS_COMPILE" "$UBOOT_BIN_NAME" "$OUTFILE_boot_bin" "$ATF_PLAT"
    fi
    if [ -n "$SYTERKIT_BOARD_FILE" ]; then
        compile_syterkit "$PATH_SOURCE" "$SYTERKIT_GIT" "$SYTERKIT_BRANCH" \
            "$SYTERKIT_BOARD_FILE" "$SYTERKIT_OUT_BIN" "$OUTFILE_boot_bin"
    fi
    pack_boot_deb "$PATH_TMP" "$ENTER_board_name" "$OUTFILE_boot_bin" "$PATH_save_boot_files" \
        "$OUTDIR_boot_package" "$CHIP_ARCH"
}

if [ $# -eq 0 ]; then
    # 如果调用本脚本时没有传入参数,则弹出选择窗口
    ENTER_board_name=$(basename $(MENU_choose_board $PATH_board))
    if [ $? -ne 0 ]; then
        echo "$ENTER_board_name"
        exit
    fi
else
    if [ $1 == $FLAG_SCRIPT_get_need ]; then
        echo "$FLAG_SCRIPT_NEED_board"
        exit
    fi
    ENTER_board_name=$1
fi
echo "ENTER_board_name = ${ENTER_board_name}"
[[ -z ${ENTER_board_name} ]] && exit
build_bootloader $ENTER_board_name
