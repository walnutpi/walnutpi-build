#!/bin/bash
PATH_PROJECT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
PATH_SCRIPT="${PATH_PROJECT_DIR}/scripts"
source "${PATH_SCRIPT}/common.sh"
source "${PATH_SCRIPT}/option.sh"
source "${PATH_SCRIPT}/menu.sh"
source "${PATH_SCRIPT}/path.sh"

source "${PATH_SCRIPT}/build_bootloader.sh"
source "${PATH_SCRIPT}/build_kernel.sh"
source "${PATH_SCRIPT}/build_rootfs.sh"
source "${PATH_SCRIPT}/build_image.sh"

reload_env() {
    source "${PATH_SCRIPT}/path.sh"
}


ENTER_board_name=$OPT_user_no_choose
ENTER_build_parts=$OPT_user_no_choose
ENTER_boot_rebuild_flag=$OPT_user_no_choose
ENTER_kernel_rebuild_flag=$OPT_user_no_choose
ENTER_os_ver=$OPT_user_no_choose
ENTER_rootfs_type=$OPT_user_no_choose

START_DATE=$(date)
LOG_START_TIME=$(date +%m-%d_%H:%M)



BUILD_ARGS=$@
para_desc () {
    echo -e "  -b : choose board"
    for dir in $(ls -d $PATH_board/*/ 2>/dev/null); do
        local dirname=$(basename "$dir")
        echo -e "\t-b $dirname"
    done
    echo ""
    echo -e "  -p : choose which part to compile"
    echo -e "\t-p $OPT_part_image"
    echo -e "\t-p $OPT_part_bootloader"
    echo -e "\t-p $OPT_part_kernel"
    echo -e "\t-p $OPT_part_rootfs"
    echo -e "\t-p $OPT_part_pack_rootfs"
    echo -e "\t-p $OPT_part_pack_image"
    echo ""
    echo -e "  -v : choose the rootfs version"
    echo -e "\t-v $OPT_os_debian12"
    echo -e "\t-v $OPT_os_ubuntu22"
    echo ""
    echo -e "  -t : choose the rootfs type"
    echo -e "\t-t $OPT_rootfs_server"
    echo -e "\t-t $OPT_rootfs_desktop"
    echo ""
    echo -e "  $OPT_skip_boot : Skip compilation boot when compiling an image"
    echo -e "  $OPT_skip_kernel : Skip compilation kernel when compiling an image"
}

while [ "x$#" != "x0" ];
do
    if [ "x$1" == "x" ]; then
        shift
        elif [ "x$1" == "x-h" ] || [ "x$1" == "x-help" ]; then
        para_desc
        exit
        
        elif [ "x$1" == "x-b" ]; then
        ENTER_board_name="${PATH_board}/$2"
        shift
        shift

        elif [ "x$1" == "x-p" ]; then
        if [ $ENTER_boot_rebuild_flag == $OPT_user_no_choose ];then ENTER_boot_rebuild_flag="$OPT_YES"; fi
        if [ $ENTER_kernel_rebuild_flag == $OPT_user_no_choose ];then ENTER_kernel_rebuild_flag="$OPT_YES"; fi
        ENTER_build_parts="$2"
        shift
        shift

        elif [ "x$1" == "x-v" ]; then
        ENTER_os_ver="$2"
        shift
        shift

        elif [ "x$1" == "x-t" ]; then
        ENTER_rootfs_type="$2"
        shift
        shift
        
        elif [ "x$1" == "x$OPT_skip_boot" ]; then
        ENTER_boot_rebuild_flag=$OPT_NO
        shift

        elif [ "x$1" == "x$OPT_skip_kernel" ]; then
        ENTER_kernel_rebuild_flag=$OPT_NO
        shift
        
    else
        para_desc
        exit
        
    fi
done

# 获取用户输入
reload_env
if [ $ENTER_board_name == $OPT_user_no_choose ]; then
    ENTER_board_name=$(MENU_choose_board $PATH_board)
    [[ -z ${ENTER_board_name} ]] && exit
fi

if [ $ENTER_build_parts == $OPT_user_no_choose ]; then
    ENTER_build_parts=$(MENU_choose_parts)
    [[ -z ${ENTER_build_parts} ]] && exit
fi

case "$ENTER_build_parts" in
    "$OPT_part_pack_rootfs" | "$OPT_part_pack_image" | "$OPT_part_rootfs" | "$OPT_part_image")
        if [ $ENTER_os_ver == $OPT_user_no_choose ]; then
            ENTER_os_ver=$(MENU_choose_os)
            [[ -z ${ENTER_os_ver} ]] && exit
        fi
        if [ $ENTER_rootfs_type == $OPT_user_no_choose ]; then
            ENTER_rootfs_type=$(MENU_choose_rootfs_type)
            [[ -z ${ENTER_rootfs_type} ]] && exit
        fi
esac

source $ENTER_board_name/board.conf
PATH_OUTPUT_BOARD=${PATH_OUTPUT}/${ENTER_board_name##*/}
echo "PATH_OUTPUT_BOARD=${PATH_OUTPUT_BOARD}"
create_dir $PATH_OUTPUT_BOARD
reload_env

if [ "$ENTER_build_parts" == "$OPT_part_image" ] && [ -d ${OUTDIR_boot_package} ]; then
    if [ "$ENTER_boot_rebuild_flag" == $OPT_user_no_choose ]; then
        ENTER_boot_rebuild_flag=$(MENU_sikp_boot)
        [[ -z ${ENTER_boot_rebuild_flag} ]] && exit
    fi
fi
if [ "$ENTER_build_parts" == "$OPT_part_image" ] && [ -d ${OUTDIR_kernel_package} ]; then
    if [ "$ENTER_kernel_rebuild_flag" == $OPT_user_no_choose ]; then
        ENTER_kernel_rebuild_flag=$(MENU_sikp_kernel)
        [[ -z ${ENTER_kernel_rebuild_flag} ]] && exit
    fi
fi


if [ ! -d ${FLAG_DIR_NO_FIRST} ]; then
    apt update
    exit_if_last_error
    apt install -y gcc-arm-none-eabi cmake  debian-archive-keyring qemu-user-static curl debootstrap kpartx git bison flex swig libssl-dev device-tree-compiler u-boot-tools make python3 python3-dev parted dosfstools
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


# exec 3>&1 4>&2
# exec > >(tee -a ${LOG_FILE}) 2>&1
reload_env

case "$ENTER_build_parts" in
    "$OPT_part_bootloader" )
        build_bootloader
    ;;
    "$OPT_part_kernel")
        build_kernel
    ;;
    "$OPT_part_rootfs")
        generate_tmp_rootfs
    ;;
    "$OPT_part_pack_rootfs")
        pack_rootfs
    ;;
    "$OPT_part_pack_image")
        build_image
    ;;
    "$OPT_part_image")
        if [ -z ${ENTER_boot_rebuild_flag} ] || [ ${ENTER_boot_rebuild_flag} == "$OPT_YES" ] ; then
            build_bootloader
        fi
        if [ -z ${ENTER_kernel_rebuild_flag} ] || [ ${ENTER_kernel_rebuild_flag} == "$OPT_YES" ] ; then
            build_kernel
        fi
        generate_tmp_rootfs
        pack_rootfs
        build_image
    ;;
esac

# exec 1>&3 2>&4
# exec 3>&- 4>&-

cd $PATH_LOG
# sed -i 's/\x1b\[[0-9;]*m//g' ${PATH_LOG}/*.log


echo -e "开始时间\t${START_DATE}"
echo -e "结束时间\t$(date)"