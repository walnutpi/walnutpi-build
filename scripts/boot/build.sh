#!/bin/bash
# scripts/boot/build.sh — bootloader 构建入口

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

source "${SCRIPT_DIR}/__uboot.sh"
source "${SCRIPT_DIR}/__syterkit.sh"
source "${SCRIPT_DIR}/__pack.sh"

# 构建bootloader
# $1 为板卡名
build_bootloader() {
    local ENTER_board_name=${PATH_board}/${1}
    source $ENTER_board_name/board.conf
    create_dir "${PATH_OUTPUT}/${1}"
    if [ ! -z $TOOLCHAIN_DOWN_URL ]; then

        USE_CROSS_COMPILE="${PATH_TOOLCHAIN}/${TOOLCHAIN_FILE_NAME}/bin/${CROSS_COMPILE}"
        if [ ! -f "${USE_CROSS_COMPILE}gcc" ]; then
            TOOLCHAIN_FILE_NAME=$(basename "$TOOLCHAIN_DOWN_URL")
            wget -P ${PATH_TOOLCHAIN} $TOOLCHAIN_DOWN_URL
            run_status "unzip toolchain" tar -zxvf ${PATH_TOOLCHAIN}/${TOOLCHAIN_FILE_NAME} -C $PATH_TOOLCHAIN
        fi
    else
        if [ ! -f /usr/bin/${CROSS_COMPILE}gcc ]; then
            apt install ${TOOLCHAIN_NAME_IN_APT}
        fi
        USE_CROSS_COMPILE="${CROSS_COMPILE}"

    fi

    local OUTDIR_boot_package=$(_path_outdir_boot "$1")
    local OUTFILE_boot_bin=$(_path_outfile_boot "$1")
    local OUTFILE_boot_bin_1M="${OUTDIR_boot_package}/boot_1M.bin"
    local OUTFILE_boot_bin_2M="${OUTDIR_boot_package}/boot_2M.bin"
    local PATH_save_boot_files="${ENTER_board_name}/boot"

    if [ -d "$OUTDIR_boot_package" ]; then
        rm -r "$OUTDIR_boot_package"
    fi
    create_dir "$OUTDIR_boot_package"
    mkdir -p "$OUTDIR_boot_package"

    if [ -n "$UBOOT_CONFIG" ]; then
        if [ -n "$ATF_GIT" ]; then
            compile_atf "$PATH_SOURCE" "$ATF_GIT" "$ATF_BRANCH" "$ATF_PLAT" "$USE_CROSS_COMPILE"
        fi
        compile_uboot "$PATH_SOURCE" "$UBOOT_GIT" "$UBOOT_BRANCH" "$UBOOT_CONFIG" \
            "$USE_CROSS_COMPILE" "$ATF_PLAT"

        local uboot_dirname="${PATH_SOURCE}/$(basename "$UBOOT_GIT" .git)-$UBOOT_BRANCH"
        if [ "x$UBOOT_BIN_NAME" != "x" ]; then
            local uboot_bin_file="${uboot_dirname}/${UBOOT_BIN_NAME}"
            cp "$uboot_bin_file" "$OUTFILE_boot_bin"
        fi
        if [ "x$UBOOT_BIN_NAME_2M" != "x" ]; then
            cp "${uboot_dirname}/${UBOOT_BIN_NAME_2M}" "$OUTFILE_boot_bin_2M"
        fi
        if [ "x$UBOOT_BIN_NAME_1M" != "x" ]; then
            cp "${uboot_dirname}/${UBOOT_BIN_NAME_1M}" "$OUTFILE_boot_bin_1M"
        fi

    fi
    if [ -n "$SYTERKIT_BOARD_FILE" ]; then
        compile_syterkit "$PATH_SOURCE" "$SYTERKIT_GIT" "$SYTERKIT_BRANCH" \
            "$SYTERKIT_BOARD_FILE" "$SYTERKIT_OUT_BIN" "$OUTFILE_boot_bin"
    fi

    pack_boot_deb "$PATH_TMP" "$ENTER_board_name" "$OUTDIR_boot_package" "$PATH_save_boot_files" \
        "$OUTDIR_boot_package" "$CHIP_ARCH"
}

# CLI 入口
if [ $# -eq 0 ]; then
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
