#!/bin/bash
# 获取文件所在路径

PATH_PROJECT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/scripts/common.sh"
source "${SCRIPT_DIR}/scripts/path.sh"
source "${SCRIPT_DIR}/scripts/option.sh"
source "${SCRIPT_DIR}/scripts/menu.sh"
source "${SCRIPT_DIR}/scripts/compile_kernel.sh"
source "${SCRIPT_DIR}/scripts/pack_kernel_deb.sh"

# 构建bootloader
# $1 为板级配置文件夹的路径
main() {

    local ENTER_board_name=$1
    source $ENTER_board_name/board.conf
    PATH_OUTPUT_BOARD=${PATH_OUTPUT}/${ENTER_board_name##*/}
    echo "PATH_OUTPUT_BOARD=${PATH_OUTPUT_BOARD}"

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
    SOURCE_kernel="${PATH_SOURCE}/$(basename "$LINUX_GIT" .git)-$LINUX_BRANCH"
    cd $PATH_SOURCE
    if [ ! -d $SOURCE_kernel ]; then
        clone_branch $LINUX_GIT $LINUX_BRANCH $SOURCE_kernel
    fi

    compile_kernel $SOURCE_kernel $LINUX_CONFIG $USE_CROSS_COMPILE $CHIP_ARCH
    OUTDIR_kernel_package=${PATH_OUTPUT_BOARD}/kernel
    if [ -d $OUTDIR_kernel_package ]; then
        rm -r $OUTDIR_kernel_package
    fi
    create_dir $OUTDIR_kernel_package
    pack_kernel_Image $PATH_PROJECT_DIR $SOURCE_kernel $CHIP_ARCH $PATH_TMP $LINUX_CONFIG $LINUX_BRANCH $BOARD_NAME $OUTDIR_kernel_package
    pack_kernel_dtb $PATH_PROJECT_DIR $SOURCE_kernel $CHIP_ARCH $PATH_TMP $LINUX_CONFIG $LINUX_BRANCH $BOARD_NAME $OUTDIR_kernel_package
    pack_kernel_modules $PATH_PROJECT_DIR $SOURCE_kernel $CHIP_ARCH $PATH_TMP $LINUX_CONFIG $LINUX_BRANCH $BOARD_NAME $OUTDIR_kernel_package
    pack_kernel_headers $PATH_PROJECT_DIR $SOURCE_kernel $CHIP_ARCH $PATH_TMP $LINUX_CONFIG $LINUX_BRANCH $BOARD_NAME $OUTDIR_kernel_package $USE_CROSS_COMPILE $LINUX_GIT $TOOLCHAIN_FILE_NAME $TOOLCHAIN_NAME_IN_APT
}

if [ $# -eq 0 ]; then
    # 如果调用本脚本时没有传入参数,则弹出选择窗口
    ENTER_board_name=$(MENU_choose_board $PATH_board)
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
