#!/bin/bash

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

# 如果LOG_START_TIME没有定义，则定义它
if [ -z "$LOG_START_TIME" ]; then
    LOG_START_TIME=$(date +%m-%d_%H:%M)
fi
LOG_MONTH_DIR="${PATH_LOG}/$(date +%Y-%m)"
LOG_FILE="${LOG_MONTH_DIR}/${LOG_START_TIME}.log"
create_dir $LOG_MONTH_DIR

FLAG_DIR="${PATH_TMP}/FLAGS"
FLAG_DIR_NO_FIRST="${FLAG_DIR}/not_first"

# --- boot ---
_path_outdir_boot()  { local board_name=$1; echo "${PATH_OUTPUT}/${board_name}/boot"; }
_path_outfile_boot() { local board_name=$1; echo "${PATH_OUTPUT}/${board_name}/boot/boot.bin"; }

# --- kernel ---
_path_outdir_kernel() { local board_name=$1; echo "${PATH_OUTPUT}/${board_name}/kernel"; }

# --- rootfs ---
_path_outfile_rootfs_tar() { local board_name=$1 os_ver=$2 rootfs_type=$3; echo "${PATH_OUTPUT}/${board_name}/rootfs_${os_ver}_${rootfs_type}.tar.gz"; }
_path_tmp_rootfs_build()   { local board_model=$1 os_ver=$2 rootfs_type=$3; echo "${PATH_TMP}/rootfs-build/${board_model}_${os_ver}_${rootfs_type}"; }
_path_file_apt_base()       { local board_name=$1 os_ver=$2; echo "${PATH_board}/${board_name}/${os_ver}/apt-base"; }
_path_file_apt_del()        { local board_name=$1 os_ver=$2; echo "${PATH_board}/${board_name}/${os_ver}/apt-del"; }
_path_file_apt_desktop()    { local board_name=$1 os_ver=$2; echo "${PATH_board}/${board_name}/${os_ver}/apt-desktop"; }
_path_file_apt_wpi_base()   { local board_name=$1 os_ver=$2; echo "${PATH_board}/${board_name}/${os_ver}/wpi-base"; }
_path_file_apt_wpi_desk()   { local board_name=$1 os_ver=$2; echo "${PATH_board}/${board_name}/${os_ver}/wpi-desktop"; }
_path_file_pip_list()       { local board_name=$1 os_ver=$2; echo "${PATH_board}/${board_name}/${os_ver}/pip"; }

# --- 镜像 ---
_path_tmp_img_disk1()   { local board_name=$1 os_ver=$2 rootfs_type=$3; echo "${PATH_TMP}/PART1-${board_name}-${os_ver}_${rootfs_type}"; }
_path_tmp_img_disk2()   { local board_name=$1 os_ver=$2 rootfs_type=$3; echo "${PATH_TMP}/PART2-${board_name}-${os_ver}_${rootfs_type}"; }
_path_tmp_mount_disk1() { local board_name=$1 os_ver=$2 rootfs_type=$3; echo "${PATH_TMP}/MOUNT-PART1-${board_name}-${os_ver}_${rootfs_type}"; }
_path_tmp_mount_disk2() { local board_name=$1 os_ver=$2 rootfs_type=$3; echo "${PATH_TMP}/MOUNT-PART2-${board_name}-${os_ver}_${rootfs_type}"; }
_path_out_img_file()    { local version=$1 rootfs_type=$2 board_name=$3 linux_branch=$4 os_ver=$5; echo "${PATH_OUTPUT}/V${version}_$(date +%m-%d)_${rootfs_type}_${board_name}_${linux_branch}_${os_ver}"; }


