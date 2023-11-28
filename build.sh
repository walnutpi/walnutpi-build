#!/bin/bash

PATH_PWD="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
PATH_SOURCE="${PATH_PWD}/source"
PATH_OUTPUT="${PATH_PWD}/output"
PATH_TMP="${PATH_PWD}/.tmp"
PATH_LOG="${PATH_PWD}/log"
PATH_TOOLCHAIN="${PATH_PWD}/toolchain"
PATH_BOOTFILE="${PATH_PWD}/boot"

PATH_SF_LIST="${PATH_PWD}/software-list"

FILE_PIP_LIST="${PATH_SF_LIST}/pip"
FILE_APT_BASE="${PATH_SF_LIST}/apt-base"
FILE_APT_DESKTOP="${PATH_SF_LIST}/apt-desktop"
FILE_APT_BASE_BOARD=""
FILE_APT_DESKTOP_BOARD=""



CONF_DIR=""
# PATH_S_FS_USER=""
# PATH_S_FS_USER_RESOURCE=""

START_DATE=$(date)

if [ ! -d $PATH_SOURCE ]; then
    mkdir $PATH_SOURCE
fi
if [ ! -d $PATH_OUTPUT ]; then
    mkdir $PATH_OUTPUT
fi
if [ ! -d $PATH_TMP ]; then
    mkdir $PATH_TMP
fi
if [ ! -d $PATH_LOG ]; then
    mkdir $PATH_LOG
fi

if [ ! -d $PATH_TOOLCHAIN ]; then
    mkdir $PATH_TOOLCHAIN
fi

if [ ! -f $FILE_PIP_LIST ]; then
    touch $FILE_PIP_LIST
    touch $FILE_APT_BASE
    touch $FILE_APT_DESKTOP
    echo "Please add your configuration to the file ${FILE_PIP_LIST} ${FILE_APT_BASE} ${FILE_APT_DESKTOP}"
    exit
fi
if [ ! -f $FILE_APT_BASE ]; then
    echo "Please add your configuration to the file ${FILE_APT_BASE}"
    exit
fi
if [ ! -f $FILE_APT_DESKTOP ]; then
    echo "Please add your configuration to the file ${FILE_APT_DESKTOP}"
    exit
fi



TTY_X=$(($(stty size | awk '{print $2}')-6)) 			# determine terminal width
TTY_Y=$(($(stty size | awk '{print $1}')-6)) 			# determine terminal height
backtitle="Walnut Pi building script"
menustr=""

# 获取 board 文件夹下所有的文件夹
dirs=$(find ${PATH_PWD}/board -mindepth 1 -maxdepth 1 -type d)
for dir in $dirs; do
    dirname=$(basename "$dir")
    options+=("$dir" "$dirname")
done

titlestr="Choose Board"
CONF_DIR=$(whiptail --title "${titlestr}" --backtitle "${backtitle}" --notags \
    --menu "${menustr}" "${TTY_Y}" "${TTY_X}" $((TTY_Y - 8))  \
    --cancel-button Exit --ok-button Select "${options[@]}" \
    3>&1 1>&2 2>&3)
unset options
echo $CONF_DIR
[[ -z $CONF_DIR ]] && exit

# PATH_S_FS_USER="${CONF_DIR}/script"
# PATH_S_FS_USER_RESOURCE="${PATH_S_FS_USER}/resource"

FILE_APT_BASE_BOARD="${CONF_DIR}/apt-base"
FILE_APT_DESKTOP_BOARD="${CONF_DIR}/apt-desktop"

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


source "${PATH_PWD}"/scripts/common.sh

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


# if [ $DEBUG -eq 0 ]; then
    apt update
    exit_if_last_error
    apt install qemu-user-static debootstrap kpartx git bison flex swig libssl-dev device-tree-compiler u-boot-tools make python3 python3-dev -y
    exit_if_last_error
# fi

if [ ! -f "${FILE_CROSS_COMPILE}gcc" ]; then
    wget -P ${PATH_TOOLCHAIN}  $TOOLCHAIN_DOWN_URL
    run_status "unzip toolchain" tar -xvf  ${PATH_TOOLCHAIN}/${TOOLCHAIN_FILE_NAME}.tar.xz -C $PATH_TOOLCHAIN
    
fi



exec 3>&1 4>&2
exec > >(tee -a ${PATH_LOG}/$(date +%m-%d_%H:%M).log) 2>&1
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
        # compile_uboot
        # compile_kernel
        create_rootfs
        do_pack
    ;;
esac

exec 1>&3 2>&4
exec 3>&- 4>&-

cd $PATH_LOG
sed -i 's/\x1b\[[0-9;]*m//g' ${PATH_LOG}/*.log


echo -e "开始时间\t${START_DATE}"
echo -e "结束时间\t$(date)"