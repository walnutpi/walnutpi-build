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
FILE_PIP_LIST="${PATH_SF_LIST}/pip"



FLAG_DIR="${PATH_TMP}/FLAGS"
FLAG_DIR_NO_FIRST="${FLAG_DIR}/not_first"

# 内核编译相关
PATH_KERNEL="${PATH_SOURCE}/$(basename "$LINUX_GIT" .git)-$LINUX_BRANCH"
PATH_OUTPUT_KERNEL_PACKAGE=${PATH_OUTPUT_BOARD}/kernel

# 编译bootloader相关
PATH_OUTPUT_BOOT_PACKAGE=${PATH_OUTPUT_BOARD}/boot
PATH_OUTPUT_BOOT_BIN=${PATH_OUTPUT_BOOT_PACKAGE}/boot.bin

# 生成rootfs相关
FILE_ROOTFS_TAR="${PATH_OUTPUT_BOARD}/rootfs_${OPT_os_ver}_${OPT_rootfs_type}.tar.gz"
PATH_ROOTFS=${PATH_TMP}/${BOARD_MODEL}_${OPT_os_ver}_${OPT_rootfs_type}

FILE_APT_BASE="${OPT_board_name}/${OPT_os_ver}/apt-base"
FILE_APT_DESKTOP="${OPT_board_name}/${OPT_os_ver}/apt-desktop"
FILE_APT_BASE_BOARD="${OPT_board_name}/${OPT_os_ver}/wpi-base"
FILE_APT_DESKTOP_BOARD="${OPT_board_name}/${OPT_os_ver}/wpi-desktop"
