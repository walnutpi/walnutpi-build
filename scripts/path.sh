#!/bin/bash

# PATH_PWD="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
PATH_board="${PATH_PWD}/board"
PATH_SOURCE="${PATH_PWD}/source"
PATH_OUTPUT="${PATH_PWD}/output"
PATH_TMP="${PATH_PWD}/.tmp"
PATH_LOG="${PATH_PWD}/log"
PATH_TOOLCHAIN="${PATH_PWD}/toolchain"
create_dir $PATH_SOURCE
create_dir $PATH_OUTPUT
create_dir $PATH_TMP
create_dir $PATH_LOG
create_dir $PATH_TOOLCHAIN

PATH_SF_LIST="${PATH_PWD}/software-list"



FLAG_DIR="${PATH_TMP}/FLAGS"
FLAG_DIR_NO_FIRST="${FLAG_DIR}/not_first"

# 内核编译相关
SOURCE_kernel="${PATH_SOURCE}/$(basename "$LINUX_GIT" .git)-$LINUX_BRANCH"
OUTDIR_kernel_package=${PATH_OUTPUT_BOARD}/kernel

# 编译bootloader相关
OUTDIR_boot_package=${PATH_OUTPUT_BOARD}/boot
OUTFILE_boot_bin=${OUTDIR_boot_package}/boot.bin

# 生成rootfs相关
OUTFILE_rootfs_tar="${PATH_OUTPUT_BOARD}/rootfs_${ENTER_os_ver}_${ENTER_rootfs_type}.tar.gz"
PATH_ROOTFS=${PATH_TMP}/${BOARD_MODEL}_${ENTER_os_ver}_${ENTER_rootfs_type}
FILE_apt_base="${ENTER_board_name}/${ENTER_os_ver}/apt-base"
FILE_apt_desktop="${ENTER_board_name}/${ENTER_os_ver}/apt-desktop"
FILE_apt_base_board="${ENTER_board_name}/${ENTER_os_ver}/wpi-base"
FILE_apt_desktop_board="${ENTER_board_name}/${ENTER_os_ver}/wpi-desktop"
FILE_pip_list="${PATH_SF_LIST}/pip"
