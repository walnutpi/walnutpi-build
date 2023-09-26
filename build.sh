#!/bin/bash

PATH_PWD="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
# PATH_RESOURCE="${PATH_PWD}/resource"
PATH_SOURCE="${PATH_PWD}/source"
PATH_OUTPUT="${PATH_PWD}/output"
PATH_TMP="${PATH_PWD}/.tmp"
PATH_TOOLCHAIN="${PATH_PWD}/toolchain"

PATH_BOOTFILE="${PATH_PWD}/boot"

PATH_FS_BUILD="${PATH_PWD}/fs-build"
PATH_S_FS_BASE="${PATH_FS_BUILD}/script/base"
PATH_S_FS_BASE_RESOURCE="${PATH_S_FS_BASE}/resource"
PATH_S_FS_DESK="${PATH_FS_BUILD}/script/desktop"
PATH_S_FS_DESK_RESOURCE="${PATH_S_FS_DESK}/resource"

FILE_PIP_LIST="${PATH_FS_BUILD}/pip-list"
FILE_APT_BASE="${PATH_FS_BUILD}/apt-list/base"
FILE_APT_DESKTOP="${PATH_FS_BUILD}/apt-list/desktop"

PATH_SERVICE="${PATH_FS_BUILD}/service"

CONF_DIR=""
PATH_S_FS_USER="${CONF_DIR}/script"
PATH_S_FS_USER_RESOURCE="${PATH_S_FS_USER}/resource"



if [ ! -d $PATH_SOURCE ]; then
    mkdir $PATH_SOURCE
fi
if [ ! -d $PATH_OUTPUT ]; then
    mkdir $PATH_OUTPUT
fi
if [ ! -d $PATH_TOOLCHAIN ]; then
    mkdir $PATH_TOOLCHAIN
fi



TTY_X=$(($(stty size | awk '{print $2}')-6)) 			# determine terminal width
TTY_Y=$(($(stty size | awk '{print $1}')-6)) 			# determine terminal height
backtitle="Walnut Pi building script" 
menustr=""

# 获取 board 文件夹下所有的文件夹
dirs=$(find board -mindepth 1 -maxdepth 1 -type d)
for dir in $dirs; do
    dirname=$(basename "$dir")
    options+=("$PATH_PWD/$dir" "$dirname")
done

titlestr="Choose Board"
CONF_DIR=$(whiptail --title "${titlestr}" --backtitle "${backtitle}" --notags \
            --menu "${menustr}" "${TTY_Y}" "${TTY_X}" $((TTY_Y - 8))  \
            --cancel-button Exit --ok-button Select "${options[@]}" \
            3>&1 1>&2 2>&3)
unset options
echo $CONF_DIR
[[ -z $CONF_DIR ]] && exit

PATH_S_FS_USER="${CONF_DIR}/script"
PATH_S_FS_USER_RESOURCE="${PATH_S_FS_USER}/resource"


titlestr="Choose an option"
options+=("image"	 "Full OS image for flashing")
options+=("u-boot"	 "U-boot bin")
options+=("kernel"	 "Kernel bin")
options+=("rootfs"	 "Rootfs tar")
BUILD_OPT=$(whiptail --title "${titlestr}" --backtitle "${backtitle}" --notags \
            --menu "${menustr}" "${TTY_Y}" "${TTY_X}" $((TTY_Y - 8))  \
            --cancel-button Exit --ok-button Select "${options[@]}" \
            3>&1 1>&2 2>&3)
unset options
echo $BUILD_OPT
[[ -z $BUILD_OPT ]] && exit



source $CONF_DIR/$(basename "$CONF_DIR").conf

FILE_CROSS_COMPILE="${PATH_TOOLCHAIN}/${TOOLCHAIN_FILE_NAME}/bin/${CROSS_COMPILE}"



source "${PATH_PWD}"/scripts/compile.sh
source "${PATH_PWD}"/scripts/rootfs.sh
source "${PATH_PWD}"/scripts/pack.sh

case "$BUILD_OPT" in
    "rootfs")
        choose_rootfs
        ;;
    "image")
        choose_rootfs

esac

echo "apt install software"

source "${PATH_PWD}"/scripts/common.sh

apt update
exit_if_last_error
apt install qemu-user-static debootstrap kpartx git bison flex swig libssl-dev device-tree-compiler u-boot-tools make python3 python3-dev -y
exit_if_last_error

if [ ! -f "${FILE_CROSS_COMPILE}gcc" ]; then
    # echo "解压$FILE_CROSS_COMPILE"
    # sudo tar czpvf - gcc-arm-9.2-2019.12-x86_64-aarch64-none-linux-gnu/ | split -d -b 80M - gcc-arm-9.2-2019.12-x86_64-aarch64-none-linux-gnu.tar
    # run_status "unzip toolchain" cat ${PATH_RESOURCE}/${TOOLCHAIN_FILE_NAME}.tar* | tar xzpvf - -C $PATH_TOOLCHAIN
    wget -P ${PATH_TOOLCHAIN}  $TOOLCHAIN_DOWN_URL
    run_status "unzip toolchain" tar -xvf  ${PATH_TOOLCHAIN}/${TOOLCHAIN_FILE_NAME}.tar.xz -C $PATH_TOOLCHAIN
    
fi

case "$BUILD_OPT" in
    "u-boot")
        compile_uboot
        ;;
    "kernel")
        compile_kernel
        ;;
    "rootfs")
        compile_kernel
        create_rootfs
        ;;
    "image")
        compile_uboot
        compile_kernel
        create_rootfs
        do_pack
        
esac
