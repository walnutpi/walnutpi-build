#!/bin/bash
PATH_PROJECT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
PATH_SCRIPT="${PATH_PROJECT_DIR}/scripts"
source "${PATH_SCRIPT}/common.sh"
source "${PATH_SCRIPT}/option.sh"
source "${PATH_SCRIPT}/menu.sh"
source "${PATH_SCRIPT}/path.sh"

reload_env() {
    source "${PATH_SCRIPT}/path.sh"
}

ENTER_board_name=$OPT_user_no_choose
ENTER_boot_rebuild_flag=$OPT_user_no_choose
ENTER_kernel_rebuild_flag=$OPT_user_no_choose
ENTER_os_ver=$OPT_user_no_choose
ENTER_rootfs_type=$OPT_user_no_choose
ENTER_img_file=$OPT_user_no_choose

START_DATE=$(date)
LOG_START_TIME=$(date +%m-%d_%H:%M)

BUILD_ARGS=$@
para_desc() {
    echo -e "  -b : choose board"
    for dir in $(ls -d $PATH_board/*/ 2>/dev/null); do
        local dirname=$(basename "$dir")
        echo -e "\t-b $dirname"
    done
    echo ""
    echo -e "  -v : choose the rootfs version"
    echo -e "\t-v $OPT_os_debian12_burn"
    echo -e "\t-v $OPT_os_debian12"
    echo -e "\t-v $OPT_os_ubuntu22"
    echo -e "\t-v $OPT_os_ubuntu24"
    echo ""
    echo -e "  -t : choose the rootfs type"
    echo -e "\t-t $OPT_rootfs_server"
    echo -e "\t-t $OPT_rootfs_desktop"
    echo ""
    echo -e "  $OPT_skip_boot : Skip compilation boot when compiling an image"
    echo -e "  $OPT_skip_kernel : Skip compilation kernel when compiling an image"
}

while [ "x$#" != "x0" ]; do
    if [ "x$1" == "x" ]; then
        shift
    elif [ "x$1" == "x-h" ] || [ "x$1" == "x-help" ]; then
        para_desc
        exit

    elif [ "x$1" == "x-b" ]; then
        ENTER_board_name="$2"
        shift
        shift

    elif [ "x$1" == "x-f" ]; then
        ENTER_img_file="$2"
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
    ENTER_board_name=$(basename "$ENTER_board_name")
fi

if [ $ENTER_os_ver == $OPT_user_no_choose ]; then
    ENTER_os_ver=$(MENU_choose_os)
    [[ -z ${ENTER_os_ver} ]] && exit
fi
if [ $ENTER_rootfs_type == $OPT_user_no_choose ]; then
    if [ $ENTER_os_ver == $OPT_os_debian12_burn ]; then
        ENTER_rootfs_type=$OPT_rootfs_server
        ENTER_img_file=$(MENU_choose_img_file)
        [[ -z ${ENTER_img_file} ]] && exit
    else
        ENTER_rootfs_type=$(MENU_choose_rootfs_type)
    fi
    [[ -z ${ENTER_rootfs_type} ]] && exit
fi

source ${PATH_board}/$ENTER_board_name/board.conf
PATH_OUTPUT_BOARD=${PATH_OUTPUT}/${ENTER_board_name}
echo "PATH_OUTPUT_BOARD=${PATH_OUTPUT_BOARD}"
create_dir $PATH_OUTPUT_BOARD
reload_env

if [ -d ${OUTDIR_boot_package} ]; then
    if [ "$ENTER_boot_rebuild_flag" == $OPT_user_no_choose ]; then
        ENTER_boot_rebuild_flag=$(MENU_sikp_boot)
        [[ -z ${ENTER_boot_rebuild_flag} ]] && exit
    fi
fi
if [ -d ${OUTDIR_kernel_package} ]; then
    if [ "$ENTER_kernel_rebuild_flag" == $OPT_user_no_choose ]; then
        ENTER_kernel_rebuild_flag=$(MENU_sikp_kernel)
        [[ -z ${ENTER_kernel_rebuild_flag} ]] && exit
    fi
fi

if [ ! -d ${FLAG_DIR_NO_FIRST} ]; then
    apt update
    exit_if_last_error
    apt install -y gcc-arm-none-eabi cmake debian-archive-keyring qemu-user-static curl debootstrap kpartx git bison flex swig libssl-dev device-tree-compiler u-boot-tools make python3 python3-dev parted dosfstools
    exit_if_last_error
    mkdir -p ${FLAG_DIR_NO_FIRST}
fi

if [ ! -z $TOOLCHAIN_DOWN_URL ]; then

    USE_CROSS_COMPILE="${PATH_TOOLCHAIN}/${TOOLCHAIN_FILE_NAME}/bin/${CROSS_COMPILE}"
    if [ ! -f "${USE_CROSS_COMPILE}gcc" ]; then
        wget -P ${PATH_TOOLCHAIN} $TOOLCHAIN_DOWN_URL
        run_status "unzip toolchain" tar -xvf ${PATH_TOOLCHAIN}/${TOOLCHAIN_FILE_NAME}.tar.xz -C $PATH_TOOLCHAIN
    fi
else
    if [ ! -f /usr/bin/${CROSS_COMPILE}gcc ]; then
        apt install ${TOOLCHAIN_NAME_IN_APT}
    fi
    USE_CROSS_COMPILE="${CROSS_COMPILE}"

fi


# 执行
reload_env
if [ ${ENTER_boot_rebuild_flag} == "$OPT_user_no_choose" ] || [ ${ENTER_boot_rebuild_flag} == "$OPT_YES" ]; then
    source "${PATH_PROJECT_DIR}/build-bootloader.sh" $ENTER_board_name
fi
if [ ${ENTER_kernel_rebuild_flag} == "$OPT_user_no_choose" ] || [ ${ENTER_kernel_rebuild_flag} == "$OPT_YES" ]; then
    source "${PATH_PROJECT_DIR}/build-kernel.sh" $ENTER_board_name
fi
source "${PATH_PROJECT_DIR}/build-rootfs.sh" $ENTER_board_name $ENTER_os_ver $ENTER_rootfs_type
source "${PATH_PROJECT_DIR}/pack-all.sh" $ENTER_board_name $ENTER_os_ver $ENTER_rootfs_type $ENTER_img_file



cd $PATH_LOG
# sed -i 's/\x1b\[[0-9;]*m//g' ${PATH_LOG}/*.log

echo -e "开始时间\t${START_DATE}"
echo -e "结束时间\t$(date)"
