#!/bin/bash
PATH_PWD="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
source "${PATH_PWD}"/scripts/common.sh

PATH_BOARD="${PATH_PWD}/board"
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


FLAG_DIR="${PATH_TMP}/FLAGS"
FLAG_DIR_NO_FIRST="${FLAG_DIR}/not_first"


START_DATE=$(date)

create_dir $PATH_SOURCE
create_dir $PATH_OUTPUT
create_dir $PATH_TMP
create_dir $PATH_LOG
create_dir $PATH_TOOLCHAIN


BUILD_ARGS=$@
para_desc () {
    echo -e "  -b : choose board"
    for dir in $(ls -d $PATH_BOARD/*/ 2>/dev/null); do
        local dirname=$(basename "$dir")
        echo -e "\t-b $dirname"
    done
    echo ""
    echo -e "  -p : choose which part to compile"
    echo -e "\t-p image"
    echo -e "\t-p bootloader"
    echo -e "\t-p kernel"
    echo -e "\t-p rootfs"
    echo ""
    echo -e "  -v : choose the rootfs version"
    echo -e "\t-v debian12"
    echo -e "\t-v ubuntu22"
    echo ""
    echo -e "  -t : choose the rootfs type"
    echo -e "\t-t server"
    echo -e "\t-t desktop"
    echo ""
    echo -e "  -s--boot : Skip compilation boot when compiling an image"
    echo -e "  -s--kernel : Skip compilation kernel when compiling an image"
}

while [ "x$#" != "x0" ];
do
    if [ "x$1" == "x" ]; then
        shift
        elif [ "x$1" == "x-h" ] || [ "x$1" == "x-help" ]; then
        para_desc
        exit
        
        elif [ "x$1" == "x-b" ]; then
        OPT_BOARD_NAME="${PATH_BOARD}/$2"
        shift
        shift
        elif [ "x$1" == "x-p" ]; then
        
        if [ -z $OPT_UBOOT_REBUILD_FLAG ] ;then OPT_UBOOT_REBUILD_FLAG="yes"; fi
        if [ -z $OPT_KERNEL_REBUILD_FLAG ] ;then OPT_KERNEL_REBUILD_FLAG="yes"; fi
        OPT_BUILD_MODULE="$2"
        shift
        shift
        elif [ "x$1" == "x-v" ]; then
        OPT_OS_VER="$2"
        shift
        shift
        elif [ "x$1" == "x-t" ]; then
        OPT_ROOTFS_TYPE="$2"
        shift
        shift
        elif [ "x$1" == "x-s--boot" ]; then
        OPT_UBOOT_REBUILD_FLAG="no"
        shift
        elif [ "x$1" == "x-s--kernel" ]; then
        OPT_KERNEL_REBUILD_FLAG="no"
        shift
        
    else
        para_desc
        exit
        
    fi
done

menustr=""
TTY_X=$(($(stty size | awk '{print $2}')-6)) 			# determine terminal width
TTY_Y=$(($(stty size | awk '{print $1}')-6)) 			# determine terminal height


if [ -z $OPT_BOARD_NAME ] || [ ! -d "$OPT_BOARD_NAME" ] ; then
    backtitle="Walnut Pi building script"
    
    # 获取 board 文件夹下所有的文件夹，作为选项
    dirs=$(find ${PATH_BOARD} -mindepth 1 -maxdepth 1 -type d)
    for dir in $dirs; do
        dirname=$(basename "$dir")
        options+=("$dir" "$dirname")
    done
    
    titlestr="Choose Board"
    OPT_BOARD_NAME=$(whiptail --title "${titlestr}" --backtitle "${backtitle}" --notags \
        --menu "${menustr}" "${TTY_Y}" "${TTY_X}" $((TTY_Y - 8))  \
        --cancel-button Exit --ok-button Select "${options[@]}" \
    3>&1 1>&2 2>&3)
    unset options
    echo $OPT_BOARD_NAME
    [[ -z $OPT_BOARD_NAME ]] && exit
fi
source $OPT_BOARD_NAME/board.conf
PATH_OUTPUT_BOARD=${PATH_OUTPUT}/${OPT_BOARD_NAME##*/}
echo "PATH_OUTPUT_BOARD=${PATH_OUTPUT_BOARD}"
create_dir $PATH_OUTPUT_BOARD

if [ -z $OPT_BUILD_MODULE ] ; then
    titlestr="Choose an option"
    options+=("image"	 "Full OS image for flashing")
    options+=("bootloader"	 "generate $BOOTLOADER_NAME .bin")
    options+=("kernel"	 "generate Kernel .deb")
    options+=("rootfs"	 "generate Rootfs .tar")
    options+=("pack_rootfs"	 "pack the tmp Rootfs files")
    options+=("pack_image"	 "pack the tmp files to generate image")
    OPT_BUILD_MODULE=$(whiptail --title "${titlestr}" --backtitle "${backtitle}" --notags \
        --menu "${menustr}" "${TTY_Y}" "${TTY_X}" $((TTY_Y - 8))  \
        --cancel-button Exit --ok-button Select "${options[@]}" \
    3>&1 1>&2 2>&3)
    unset options
    echo $OPT_BUILD_MODULE
    [[ -z $OPT_BUILD_MODULE ]] && exit
    
fi
source "${PATH_PWD}"/scripts/compile.sh
source "${PATH_PWD}"/scripts/rootfs.sh
source "${PATH_PWD}"/scripts/pack.sh

case "$OPT_BUILD_MODULE" in
    "pack_rootfs" | "pack_image" | "rootfs" | "image")
        choose_rootfs
esac
if [ "$OPT_BUILD_MODULE" == "image" ] && [ -f ${PATH_OUTPUT_BOARD}/${UBOOT_BIN_NAME} ]; then
    if [ -z $OPT_UBOOT_REBUILD_FLAG ]; then
        titlestr="recompile the u-boot ?"
        options+=("no"    "no")
        options+=("yes"    "yes")
        OPT_UBOOT_REBUILD_FLAG=$(whiptail --title "${titlestr}" --backtitle "${backtitle}" --notags \
            --menu "${menustr}" "${TTY_Y}" "${TTY_X}" $((TTY_Y - 8))  \
            --cancel-button Exit --ok-button Select "${options[@]}" \
        3>&1 1>&2 2>&3)
        unset options
        echo ${OPT_UBOOT_REBUILD_FLAG}
        [[ -z ${OPT_UBOOT_REBUILD_FLAG} ]] && exit
    fi
fi

if [ "$OPT_BUILD_MODULE" == "image" ] && [ -d ${PATH_KERNEL_PACKAGE} ]; then
    if [ -z $OPT_KERNEL_REBUILD_FLAG ]; then
        titlestr="recompile the KERNEL ?"
        options+=("no"    "no")
        options+=("yes"    "yes")
        OPT_KERNEL_REBUILD_FLAG=$(whiptail --title "${titlestr}" --backtitle "${backtitle}" --notags \
            --menu "${menustr}" "${TTY_Y}" "${TTY_X}" $((TTY_Y - 8))  \
            --cancel-button Exit --ok-button Select "${options[@]}" \
        3>&1 1>&2 2>&3)
        unset options
        echo ${OPT_KERNEL_REBUILD_FLAG}
        [[ -z ${OPT_KERNEL_REBUILD_FLAG} ]] && exit
    fi
fi

if [ ! -d ${FLAG_DIR_NO_FIRST} ]; then
    apt update
    exit_if_last_error
    apt install debian-archive-keyring qemu-user-static curl debootstrap kpartx git bison flex swig libssl-dev device-tree-compiler u-boot-tools make python3 python3-dev -y
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
case "$OPT_BUILD_MODULE" in
    "bootloader" )
        compile_bootloader
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
        if [ -z ${OPT_UBOOT_REBUILD_FLAG} ] || [ ${OPT_UBOOT_REBUILD_FLAG} == "yes" ] ; then
            compile_bootloader
        fi
        if [ -z ${OPT_KERNEL_REBUILD_FLAG} ] || [ ${OPT_KERNEL_REBUILD_FLAG} == "yes" ] ; then
            compile_kernel
        fi
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