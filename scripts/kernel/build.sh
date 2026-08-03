#!/bin/bash
# scripts/kernel/build.sh — kernel 构建入口

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
PATH_PROJECT_DIR="${ROOT_DIR}"

source "${ROOT_DIR}/scripts/__common.sh"
source "${ROOT_DIR}/scripts/__path.sh"
source "${ROOT_DIR}/scripts/__option.sh"
source "${ROOT_DIR}/scripts/__menu.sh"

source "${SCRIPT_DIR}/__compile.sh"
source "${SCRIPT_DIR}/__pack.sh"

# 构建kernel
# $1 为板卡名
main() {
    local ENTER_board_name=${PATH_board}/${1}
    source $ENTER_board_name/board.conf
    PATH_OUTPUT_BOARD=${PATH_OUTPUT}/${ENTER_board_name##*/}
    echo "PATH_OUTPUT_BOARD=${PATH_OUTPUT_BOARD}"

    create_dir $PATH_OUTPUT_BOARD
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
    SOURCE_kernel="${PATH_SOURCE}/$(basename "$LINUX_GIT" .git)-$LINUX_BRANCH"
    cd $PATH_SOURCE
    if [ ! -d $SOURCE_kernel ]; then
        clone_branch $LINUX_GIT $LINUX_BRANCH $SOURCE_kernel
    fi

    compile_kernel $SOURCE_kernel $LINUX_CONFIG $USE_CROSS_COMPILE $CHIP_ARCH
    if [ "x$BR2_PACKAGE_RTL8189FS" == "xy" ]; then
        ${ROOT_DIR}/scripts/package/BR2_PACKAGE_RTL8189FS.sh "${PATH_SOURCE}" "$SOURCE_kernel" "$USE_CROSS_COMPILE" "$CHIP_ARCH"
    fi
    if [ "x$BR2_PACKAGE_VVACM_DRIVER" == "xy" ]; then
        ${ROOT_DIR}/scripts/package/BR2_PACKAGE_VVACM_DRIVER.sh "${PATH_SOURCE}" "$SOURCE_kernel" "$USE_CROSS_COMPILE" "$CHIP_ARCH"
    fi
    if [ "x$BR2_PACKAGE_AIC8800_SDIO" == "xy" ]; then
        ${ROOT_DIR}/scripts/package/BR2_PACKAGE_AIC8800_SDIO.sh "${PATH_SOURCE}" "$SOURCE_kernel" "$USE_CROSS_COMPILE" "$CHIP_ARCH"
    fi
    OUTDIR_kernel_package=${PATH_OUTPUT_BOARD}/kernel
    if [ -d $OUTDIR_kernel_package ]; then
        rm -r $OUTDIR_kernel_package
    fi
    create_dir $OUTDIR_kernel_package
    pack_kernel_Image $ROOT_DIR $SOURCE_kernel $CHIP_ARCH $PATH_TMP $LINUX_CONFIG $LINUX_BRANCH $BOARD_NAME $OUTDIR_kernel_package
    pack_kernel_dtb $ROOT_DIR $SOURCE_kernel $CHIP_ARCH $PATH_TMP $LINUX_CONFIG $LINUX_BRANCH $BOARD_NAME $OUTDIR_kernel_package
    pack_kernel_modules $ROOT_DIR $SOURCE_kernel $CHIP_ARCH $PATH_TMP $LINUX_CONFIG $LINUX_BRANCH $BOARD_NAME $OUTDIR_kernel_package
    pack_kernel_headers $ROOT_DIR $SOURCE_kernel $CHIP_ARCH $PATH_TMP $LINUX_CONFIG $LINUX_BRANCH $BOARD_NAME $OUTDIR_kernel_package $USE_CROSS_COMPILE $LINUX_GIT $TOOLCHAIN_FILE_NAME $TOOLCHAIN_NAME_IN_APT
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
main $ENTER_board_name
