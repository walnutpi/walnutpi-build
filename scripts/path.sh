#!/bin/bash

# PATH_PROJECT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
PATH_board="${PATH_PROJECT_DIR}/board"
PATH_SOURCE="${PATH_PROJECT_DIR}/source"
PATH_OUTPUT="${PATH_PROJECT_DIR}/output"
PATH_TMP="${PATH_PROJECT_DIR}/.tmp"
PATH_LOG="${PATH_PROJECT_DIR}/log"
PATH_TOOLCHAIN="${PATH_PROJECT_DIR}/toolchain"
create_dir $PATH_SOURCE
create_dir $PATH_OUTPUT
create_dir $PATH_TMP
create_dir $PATH_LOG
create_dir $PATH_TOOLCHAIN

# LOG_START_TIME=$(date +%m-%d_%H:%M) #在build.sh内定义
LOG_MONTH_DIR="${PATH_LOG}/$(date +%Y-%m)"
LOG_FILE="${LOG_MONTH_DIR}/${LOG_START_TIME}.log"
create_dir $LOG_MONTH_DIR

FLAG_DIR="${PATH_TMP}/FLAGS"
FLAG_DIR_NO_FIRST="${FLAG_DIR}/not_first"

# 编译bootloader相关
OUTDIR_boot_package=${PATH_OUTPUT_BOARD}/boot
OUTFILE_boot_bin=${OUTDIR_boot_package}/boot.bin
PATH_save_boot_files="${ENTER_board_name}/boot"

# 内核编译相关
SOURCE_kernel="${PATH_SOURCE}/$(basename "$LINUX_GIT" .git)-$LINUX_BRANCH"
OUTDIR_kernel_package=${PATH_OUTPUT_BOARD}/kernel

# 生成rootfs相关
OUTFILE_rootfs_tar="${PATH_OUTPUT_BOARD}/rootfs_${ENTER_os_ver}_${ENTER_rootfs_type}.tar.gz"
TMP_rootfs_build=${PATH_TMP}/${BOARD_MODEL}_${ENTER_os_ver}_${ENTER_rootfs_type}
FILE_base_rootfs=${TMP_rootfs_build}_base_software.tar
FILE_apt_base="${ENTER_board_name}/${ENTER_os_ver}/apt-base"
FILE_apt_desktop="${ENTER_board_name}/${ENTER_os_ver}/apt-desktop"
FILE_apt_base_board="${ENTER_board_name}/${ENTER_os_ver}/wpi-base"
FILE_apt_desktop_board="${ENTER_board_name}/${ENTER_os_ver}/wpi-desktop"
FILE_pip_list="${ENTER_board_name}/${ENTER_os_ver}/pip"
PLACE_sf_list="${TMP_rootfs_build}/etc/release-apt"

# 打包镜像相关
TMP_mount_disk1="${PATH_TMP}/PART1"
TMP_mount_disk2="${PATH_TMP}/PART2"
OUT_IMG_FILE="${PATH_OUTPUT}/V${VERSION_APT}_$(date +%m-%d)_${ENTER_rootfs_type}_${BOARD_NAME}_${LINUX_BRANCH}_${ENTER_os_ver}"
