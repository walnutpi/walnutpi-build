#!/bin/bash
PATH_PWD="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
source "${PATH_PWD}"/scripts/common.sh

PATH_SOURCE="${PATH_PWD}/source"
PATH_OUTPUT="${PATH_PWD}/output"
PATH_TMP="${PATH_PWD}/.tmp"
PATH_LOG="${PATH_PWD}/log"
PATH_TOOLCHAIN="${PATH_PWD}/toolchain"
PATH_SF_LIST="${PATH_PWD}/software-list"

FILE_PIP_LIST="${PATH_SF_LIST}/pip"
FILE_APT_BASE=""
FILE_APT_DESKTOP=""
FILE_APT_BASE_BOARD=""
FILE_APT_DESKTOP_BOARD=""

DIR_BOARD=""

FLAG_DIR="${PATH_TMP}/FLAGS"
FLAG_DIR_NO_FIRST="${FLAG_DIR}/not_first"

START_DATE=$(date)

create_dir $PATH_SOURCE
create_dir $PATH_OUTPUT
create_dir $PATH_TMP
create_dir $PATH_LOG
create_dir $PATH_TOOLCHAIN


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
DIR_BOARD=$(whiptail --title "${titlestr}" --backtitle "${backtitle}" --notags \
    --menu "${menustr}" "${TTY_Y}" "${TTY_X}" $((TTY_Y - 8))  \
    --cancel-button Exit --ok-button Select "${options[@]}" \
3>&1 1>&2 2>&3)
unset options
echo $DIR_BOARD
[[ -z $DIR_BOARD ]] && exit

PATH_OUTPUT_BOARD=${PATH_OUTPUT}/${DIR_BOARD##*/}
echo "PATH_OUTPUT_BOARD=${PATH_OUTPUT_BOARD}"
create_dir $PATH_OUTPUT_BOARD


titlestr="Choose an option"
options+=("image"	 "Full OS image for flashing")
options+=("u-boot"	 "generate U-boot .bin")
options+=("kernel"	 "generate Kernel .deb")
options+=("rootfs"	 "generate Rootfs .tar")
options+=("pack_rootfs"	 "pack the tmp Rootfs files")
options+=("pack_image"	 "pack the tmp files to generate image")
BUILD_OPT=$(whiptail --title "${titlestr}" --backtitle "${backtitle}" --notags \
    --menu "${menustr}" "${TTY_Y}" "${TTY_X}" $((TTY_Y - 8))  \
    --cancel-button Exit --ok-button Select "${options[@]}" \
3>&1 1>&2 2>&3)
unset options
echo $BUILD_OPT
[[ -z $BUILD_OPT ]] && exit



source $DIR_BOARD/board.conf




source "${PATH_PWD}"/scripts/compile.sh
source "${PATH_PWD}"/scripts/rootfs.sh
source "${PATH_PWD}"/scripts/pack.sh

case "$BUILD_OPT" in
    "pack_rootfs" | "pack_image" | "rootfs" | "image")
        choose_rootfs
esac
if [ "$BUILD_OPT" == "image" ] && [ -f ${PATH_OUTPUT_BOARD}/${UBOOT_BIN_NAME} ]; then
    titlestr="recompile the u-boot ?"
    options+=("no"    "no")
    options+=("yes"    "yes")
    OPT_UBOOT_REBUILD=$(whiptail --title "${titlestr}" --backtitle "${backtitle}" --notags \
        --menu "${menustr}" "${TTY_Y}" "${TTY_X}" $((TTY_Y - 8))  \
        --cancel-button Exit --ok-button Select "${options[@]}" \
    3>&1 1>&2 2>&3)
    unset options
    echo ${OPT_UBOOT_REBUILD}
    [[ -z ${OPT_UBOOT_REBUILD} ]] && exit
fi

if [ ! -d ${FLAG_DIR_NO_FIRST} ]; then
    apt update
    exit_if_last_error
    apt install qemu-user-static debootstrap kpartx git bison flex swig libssl-dev device-tree-compiler u-boot-tools make python3 python3-dev -y
    exit_if_last_error
    mkdir -p ${FLAG_DIR_NO_FIRST}
fi

if [ ! -z $TOOLCHAIN_DOWN_URL ];then
    
    USE_CROSS_COMPILE="${PATH_TOOLCHAIN}/${TOOLCHAIN_FILE_NAME}/bin/${CROSS_COMPILE}"
    if [ ! -f "${USE_CROSS_COMPILE}gcc" ] ; then
        wget -P ${PATH_TOOLCHAIN}  $TOOLCHAIN_DOWN_URL
        run_status "unzip toolchain" tar -xvf  ${PATH_TOOLCHAIN}/${TOOLCHAIN_FILE_NAME}.tar.xz -C $PATH_TOOLCHAIN
    fi
else
    if [ ! -f /usr/bin/${CROSS_COMPILE}gcc ]; then
        apt install ${TOOLCHAIN_NAME_IN_APT}
    fi
    USE_CROSS_COMPILE="${CROSS_COMPILE}"
    
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
        generate_tmp_rootfs
    ;;
    "pack_rootfs")
        pack_rootfs
    ;;
    "image")
        if [ -z ${OPT_UBOOT_REBUILD} ] || [ ${OPT_UBOOT_REBUILD} == "yes" ] ; then
            compile_uboot
        fi
        compile_kernel
        generate_tmp_rootfs
        pack_rootfs
        do_pack
    ;;
    "pack_image")
        do_pack
    ;;
esac

exec 1>&3 2>&4
exec 3>&- 4>&-

cd $PATH_LOG
sed -i 's/\x1b\[[0-9;]*m//g' ${PATH_LOG}/*.log


echo -e "开始时间\t${START_DATE}"
echo -e "结束时间\t$(date)"