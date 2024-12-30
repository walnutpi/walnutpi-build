#!/bin/bash
PATH_PWD="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
PATH_SCRIPT="${PATH_PWD}/scripts"
source "${PATH_SCRIPT}/common.sh"
source "${PATH_SCRIPT}/menu.sh"
source "${PATH_SCRIPT}/path.sh"

source "${PATH_SCRIPT}/compile.sh"
source "${PATH_SCRIPT}/rootfs.sh"
source "${PATH_SCRIPT}/pack.sh"
source "${PATH_SCRIPT}/build_kernel.sh"
source "${PATH_SCRIPT}/build_bootloader.sh"

reload_env() {
    source "${PATH_SCRIPT}/path.sh"
}


OPT_board_name=$FLAG_menu_no_choose
OPT_build_parts=$FLAG_menu_no_choose
OPT_boot_rebuild_flag=$FLAG_menu_no_choose
OPT_kernel_rebuild_flag=$FLAG_menu_no_choose
OPT_os_ver=$FLAG_menu_no_choose
OPT_rootfs_type=$FLAG_menu_no_choose

START_DATE=$(date)



BUILD_ARGS=$@
para_desc () {
    echo -e "  -b : choose board"
    for dir in $(ls -d $PATH_board/*/ 2>/dev/null); do
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
        OPT_board_name="${PATH_board}/$2"
        shift
        shift
        elif [ "x$1" == "x-p" ]; then
        
        if [ -z $OPT_boot_rebuild_flag ] ;then OPT_boot_rebuild_flag="yes"; fi
        if [ -z $OPT_kernel_rebuild_flag ] ;then OPT_kernel_rebuild_flag="yes"; fi
        OPT_build_parts="$2"
        shift
        shift
        elif [ "x$1" == "x-v" ]; then
        OPT_os_ver="$2"
        shift
        shift
        elif [ "x$1" == "x-t" ]; then
        OPT_rootfs_type="$2"
        shift
        shift
        elif [ "x$1" == "x-s--boot" ]; then
        OPT_boot_rebuild_flag="no"
        shift
        elif [ "x$1" == "x-s--kernel" ]; then
        OPT_kernel_rebuild_flag="no"
        shift
        
    else
        para_desc
        exit
        
    fi
done


if [ $OPT_board_name == $FLAG_menu_no_choose ]; then
    OPT_board_name=$(MENU_choose_board $PATH_board)
fi

if [ $OPT_build_parts == $FLAG_menu_no_choose ]; then
    OPT_build_parts=$(MENU_choose_parts)
fi


case "$OPT_build_parts" in
    "$FLAG_OPT_part_pack_rootfs" | "$FLAG_OPT_part_pack_image" | "$FLAG_OPT_part_rootfs" | "$FLAG_OPT_part_image")
        if [ $OPT_os_ver == $FLAG_menu_no_choose ]; then
            OPT_os_ver=$(MENU_choose_os)
        fi
        if [ $OPT_rootfs_type == $FLAG_menu_no_choose ]; then
            OPT_rootfs_type=$(MENU_choose_rootfs_type)
        fi
esac

if [ "$OPT_build_parts" == "$FLAG_OPT_part_image" ] && [ -f ${PATH_OUTPUT_BOARD}/${UBOOT_BIN_NAME} ]; then
    if [ -z "$OPT_boot_rebuild_flag" ]; then
        OPT_boot_rebuild_flag=$(MENU_sikp_boot)
    fi
fi
if [ "$OPT_build_parts" == "$FLAG_OPT_part_image" ] && [ -d ${PATH_OUTPUT_KERNEL_PACKAGE} ]; then
    if [ -z "$OPT_kernel_rebuild_flag" ]; then
        OPT_kernel_rebuild_flag=$(MENU_sikp_kernel)
    fi
fi

source $OPT_board_name/board.conf
PATH_OUTPUT_BOARD=${PATH_OUTPUT}/${OPT_board_name##*/}
echo "PATH_OUTPUT_BOARD=${PATH_OUTPUT_BOARD}"
create_dir $PATH_OUTPUT_BOARD



if [ ! -d ${FLAG_DIR_NO_FIRST} ]; then
    apt update
    exit_if_last_error
    apt install -y debian-archive-keyring qemu-user-static curl debootstrap kpartx git bison flex swig libssl-dev device-tree-compiler u-boot-tools make python3 python3-dev parted dosfstools
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
reload_env

case "$OPT_build_parts" in
    "$FLAG_OPT_part_bootloader" )
        # compile_bootloader
        build_bootloader
    ;;
    "$FLAG_OPT_part_kernel")
        build_kernel
    ;;
    "$FLAG_OPT_part_rootfs")
        generate_tmp_rootfs
    ;;
    "$FLAG_OPT_part_pack_rootfs")
        pack_rootfs
    ;;
    "$FLAG_OPT_part_pack_image")
        do_pack
    ;;
    "$FLAG_OPT_part_image")
        if [ -z ${OPT_boot_rebuild_flag} ] || [ ${OPT_boot_rebuild_flag} == "$FLAG_OPT_YES" ] ; then
            # compile_bootloader
            build_bootloader
        fi
        if [ -z ${OPT_kernel_rebuild_flag} ] || [ ${OPT_kernel_rebuild_flag} == "$FLAG_OPT_YES" ] ; then
            build_kernel
        fi
        generate_tmp_rootfs
        pack_rootfs
        do_pack
    ;;
esac

exec 1>&3 2>&4
exec 3>&- 4>&-

cd $PATH_LOG
sed -i 's/\x1b\[[0-9;]*m//g' ${PATH_LOG}/*.log


echo -e "开始时间\t${START_DATE}"
echo -e "结束时间\t$(date)"