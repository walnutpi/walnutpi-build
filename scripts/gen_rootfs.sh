#!/bin/bash

APT_SOURCES_WALNUTPI="deb [trusted=yes] http://apt.walnutpi.com/debian/ bookworm main"
APT_DOMAIN="apt.walnutpi.com"
DEBIAN_BASE_URL="http://mirrors.tuna.tsinghua.edu.cn/debian/"
UBUNTU22_BASE_URL="https://mirror.tuna.tsinghua.edu.cn/ubuntu-cdimage/ubuntu-base/releases/22.04/release/ubuntu-base-22.04.4-base-arm64.tar.gz"
UBUNTU24_BASE_URL="https://mirror.tuna.tsinghua.edu.cn/ubuntu-cdimage/ubuntu-base/releases/24.04/release/ubuntu-base-24.04.2-base-arm64.tar.gz"

# 参数说明:
# $1 - base_url: Ubuntu基础镜像的下载URL
# $2 - tmp_file_name: 下载文件的临时名称
# $3 - tmp_dir: 解压目标目录
_download_ubuntu_base() {
    local base_url=$1
    local tmp_file_name=$2
    local tmp_dir=$3
    wget $base_url -O $tmp_file_name
    run_status "unzip rootfs" tar -xvf $tmp_file_name -C $tmp_dir

    # base默认没写dns服务器
    local FILE="${tmp_dir}/etc/resolv.conf"
    local LINE="nameserver 8.8.8.8"
    grep -qF -- "$LINE" "$FILE" || echo "$LINE" >>"$FILE"
}
# 参数说明:
# $1 - base_url: Debian基础镜像的下载URL
# $2 - debian_name: Debian版本名称
# $3 - tmp_dir: 解压目标目录
# $4 - chip_arch: 芯片架构
_download_debian_base() {
    local base_url=$1
    local debian_name=$2
    local tmp_dir=$3
    local chip_arch=$4

    debootstrap --foreign --verbose --arch=${chip_arch} ${debian_name} ${tmp_dir} $base_url
    exit_if_last_error

    # 完成rootfs的初始化
    cd ${tmp_dir}
    mount_chroot $tmp_dir
    LC_ALL=C LANGUAGE=C LANG=C chroot ${tmp_dir} /debootstrap/debootstrap --second-stage –verbose
    exit_if_last_error
    run_slient_when_successfuly chroot $tmp_dir /bin/bash -c "DEBIAN_FRONTEND=noninteractive  apt-get clean"
    umount_chroot $tmp_dir
}

# 下载基础rootfs或解压已有rootfs
# 参数说明:
# $1 - FILE_base_rootfs: 基础rootfs压缩包文件路径
# $2 - TMP_rootfs_build: 临时构建rootfs的目录
# $3 - ENTER_os_ver: 操作系统版本选择
_download_base_rootfs() {
    local FILE_base_rootfs=$1
    local TMP_rootfs_build=$2
    local ENTER_os_ver=$3

    if [[ -d $TMP_rootfs_build ]]; then
        run_as_silent umount_chroot $TMP_rootfs_build
        rm -r ${TMP_rootfs_build}
    fi
    mkdir ${TMP_rootfs_build}

    if [[ -f $FILE_base_rootfs ]]; then
        run_status "unzip last rootfs" tar -xvf $FILE_base_rootfs -C $TMP_rootfs_build
    else

        run_as_silent mkdir ${TMP_rootfs_build} -p
        case "${ENTER_os_ver}" in
        "${OPT_os_debian12}" | "$OPT_os_debian12_burn")
            _download_debian_base $DEBIAN_BASE_URL "bookworm" $TMP_rootfs_build arm64
            ;;
        "${OPT_os_debian11}")
            _download_debian_base $DEBIAN_BASE_URL "bullseye" $TMP_rootfs_build arm64
            ;;
        "${OPT_os_ubuntu22}")
            _download_ubuntu_base $UBUNTU22_BASE_URL $FILE_base_rootfs $TMP_rootfs_build
            ;;
        "${OPT_os_ubuntu24}")
            _download_ubuntu_base $UBUNTU24_BASE_URL $FILE_base_rootfs $TMP_rootfs_build
            ;;
        esac
        cd $TMP_rootfs_build
        tar -czf $FILE_base_rootfs ./
    fi
}
# 参数说明:
# $1 - TMP_rootfs_build: 临时构建rootfs的目录
# $2 - FILE_apt_base: 基础软件包列表文件
# $3 - FILE_apt_desktop: 桌面环境软件包列表文件
# $4 - ENTER_rootfs_type: rootfs类型 (desktop 或其他)
# $5 - PLACE_sf_list: 已安装软件包记录文件
# $6 - FILE_base_rootfs: 基础rootfs压缩包文件路径
_apt_install_base_rootfs() {
    local TMP_rootfs_build=$1
    local FILE_apt_base=$2
    local FILE_apt_desktop=$3
    local ENTER_rootfs_type=$4
    local PLACE_sf_list=$5
    local FILE_base_rootfs=$6

    # apt安装通用软件
    # cd $TMP_rootfs_build
    mount_chroot $TMP_rootfs_build

    run_status "apt update" chroot ${TMP_rootfs_build} /bin/bash -c "apt-get update"

    # 用这个文件作为安装过的软件的列表，在重复构建时节省时间
    if [[ ! -f $PLACE_sf_list ]]; then
        touch $PLACE_sf_list
    fi

    # 获取要本脚本的软件安装列表
    mapfile -t packages_build < <(grep -vE '^#|^$' ${FILE_apt_base})
    if [[ ${ENTER_rootfs_type} == "desktop" ]]; then
        mapfile -t desktop_packages < <(grep -vE '^#|^$' ${FILE_apt_desktop})
        packages_build=("${packages_build[@]}" "${desktop_packages[@]}")
    fi

    # 获取rootfs内的软件安装列表
    mapfile -t packages_rootfs < <(grep -vE '^#|^$' ${PLACE_sf_list})
    # echo ${packages_build[@]}
    packages_install=()
    packages_remove=()
    # 找出需要安装的包
    for pkg in "${packages_build[@]}"; do
        if ! [[ " ${packages_rootfs[@]} " =~ " ${pkg} " ]]; then
            packages_install+=("$pkg")
        fi
    done
    # 找出需要移除的包
    for pkg in "${packages_rootfs[@]}"; do
        if ! [[ " ${packages_build[@]} " =~ " ${pkg} " ]]; then
            packages_remove+=("$pkg")
        fi
    done

    # 安装packages_install中的包,卸载packages_remove中的包
    total=${#packages_install[@]}
    for ((i = 0; i < ${total}; i++)); do
        package=${packages_install[$i]}
        run_status "apt install [$((i + 1))/${total}] : $package " chroot $TMP_rootfs_build /bin/bash -c "DEBIAN_FRONTEND=noninteractive  apt-get install -y  ${package}"
    done
    total=${#packages_remove[@]}
    for ((i = 0; i < ${total}; i++)); do
        package=${packages_remove[$i]}
        run_status "apt remove [$((i + 1))/${total}] : $package " chroot $TMP_rootfs_build /bin/bash -c "DEBIAN_FRONTEND=noninteractive  apt-get remove -y  ${package}"
    done
    run_slient_when_successfuly chroot $TMP_rootfs_build /bin/bash -c "DEBIAN_FRONTEND=noninteractive  apt-get clean"

    # 将安装过的软件名称，都写进文件内
    if [[ -f $PLACE_sf_list ]]; then
        rm $PLACE_sf_list
    fi
    touch $PLACE_sf_list
    for package in "${packages_build[@]}"; do
        echo "$package" >>$PLACE_sf_list
    done
    umount_chroot $TMP_rootfs_build

    # 如果本次对保存的rootfs的apt软件有增删，则重设压缩包
    if [ ${#packages_install[@]} -gt 0 ] || [ ${#packages_remove[@]} -gt 0 ]; then
        rm -r $FILE_base_rootfs
        cd ${TMP_rootfs_build}
        run_status "create the tar to save now rootfs" tar -czf $FILE_base_rootfs ./
    fi

}

# 参数说明:
# $1 - TMP_rootfs_build: 临时构建rootfs的目录
# $2 - FILE_pip_list: pip软件包列表文件
_pip_install() {
    local TMP_rootfs_build=$1
    local FILE_pip_list=$2

    # pip 安装指定软件
    local LIB_DIR="${TMP_rootfs_build}/usr/lib"
    local FILE_NAME="EXTERNALLY-MANAGED"
    find $LIB_DIR -type f -name "$FILE_NAME" -delete

    if [ -f $FILE_pip_list ]; then
        mapfile -t packages < <(grep -vE '^#|^$' ${FILE_pip_list})
        local total=${#packages[@]}
        for ((i = 0; i < ${total}; i++)); do
            local package=${packages[$i]}
            # echo "pip3 [$((i+1))/${total}] : $package"
            run_status "pip3 [$((i + 1))/${total}] : $package" chroot $TMP_rootfs_build /bin/bash -c "DEBIAN_FRONTEND=noninteractive  pip3 --no-cache-dir install   ${package}"
        done
    fi
}

# 参数说明:
# $1 - PATH_SOURCE: 源代码路径
# $2 - FIRMWARE_GIT: 固件Git仓库地址
# $3 - TMP_rootfs_build: 临时构建rootfs的目录
_add_firmware() {
    local PATH_SOURCE=$1
    local FIRMWARE_GIT=$2
    local TMP_rootfs_build=$3

    cd ${PATH_SOURCE}
    local firm_dir=$(basename "${FIRMWARE_GIT}" .git)

    if [ -n "${FIRMWARE_GIT}" ]; then
        if [[ ! -d "firmware" ]]; then
            run_status "download firmware" git clone "${FIRMWARE_GIT}"
        fi
        local FIRMWARE_PATH="${TMP_rootfs_build}/lib/firmware"
        if [ ! -d $FIRMWARE_PATH ]; then
            mkdir -p $FIRMWARE_PATH
        fi
        cp -r ${firm_dir}/* $FIRMWARE_PATH
    fi
}
# 参数说明:
# $1 - TMP_rootfs_build: 临时构建rootfs的目录
# $2 - FILE_apt_base_board: 板级基础软件包列表文件
# $3 - FILE_apt_desktop_board: 板级桌面环境软件包列表文件
# $4 - ENTER_rootfs_type: rootfs类型 (desktop 或其他)
_wpi_install() {
    local TMP_rootfs_build=$1
    local FILE_apt_base_board=$2
    local FILE_apt_desktop_board=$3
    local ENTER_rootfs_type=$4

    mount_chroot $TMP_rootfs_build
    # 插入walnutpi的apt源
    apt_source_list=${TMP_rootfs_build}/etc/apt/sources.list.d/walnutpi.list
    if [ -f $apt_source_list ]; then
        rm $apt_source_list
    fi
    echo $APT_SOURCES_WALNUTPI >>$apt_source_list
    run_status "apt update" chroot ${TMP_rootfs_build} /bin/bash -c "apt-get update"

    mapfile -t packages < <(grep -vE '^#|^$' ${FILE_apt_base_board})
    if [[ ${ENTER_rootfs_type} == "desktop" ]]; then
        mapfile -t desktop_packages < <(grep -vE '^#|^$' ${FILE_apt_desktop_board})
        packages=("${packages[@]}" "${desktop_packages[@]}")
    fi
    local total=${#packages[@]}
    for ((i = 0; i < ${total}; i++)); do
        local package=${packages[$i]}
        run_status "apt [$((i + 1))/${total}] : $package " chroot $TMP_rootfs_build /bin/bash -c "DEBIAN_FRONTEND=noninteractive  apt-get -o Dpkg::Options::='--force-overwrite' install -y ${package}"
    done

    # 删除插入hosts文件的内容
    if grep -q "$APT_DOMAIN" "$TMP_rootfs_build/etc/hosts"; then
        sed -i "/$APT_DOMAIN/d" "$TMP_rootfs_build/etc/hosts"
    fi

    # 去除残余
    run_slient_when_successfuly chroot $TMP_rootfs_build /bin/bash -c "DEBIAN_FRONTEND=noninteractive  apt-get clean"
    if [ -f $apt_source_list ]; then
        rm $apt_source_list
    fi
    umount_chroot $TMP_rootfs_build
}
# 参数说明:
# $1  - TMP_rootfs_build: 临时构建rootfs的目录
# $2  - FILE_base_rootfs: 基础rootfs压缩包文件路径
# $3  - ENTER_os_ver: 操作系统版本选择
# $4  - FILE_apt_base: 基础软件包列表文件
# $5  - FILE_apt_desktop: 桌面环境软件包列表文件
# $6  - ENTER_rootfs_type: rootfs类型 (desktop 或其他)
# $7  - PLACE_sf_list: 已安装软件包记录文件
# $8  - PATH_SOURCE: 源代码路径
# $9  - FIRMWARE_GIT: 固件Git仓库地址
# $10 - FILE_pip_list: pip软件包列表文件
# $11 - FILE_apt_base_board: 板级基础软件包列表文件
# $12 - FILE_apt_desktop_board: 板级桌面环境软件包列表文件
# $13 - BOARD_MODEL: 开发板型号
# $14 - MODULES_ENABLE: 需要启用的内核模块列表
gen_rootfs() {
    local TMP_rootfs_build=$1
    local FILE_base_rootfs=$2
    local ENTER_os_ver=$3
    local FILE_apt_base=$4
    local FILE_apt_desktop=$5
    local ENTER_rootfs_type=$6
    local PLACE_sf_list=$7
    local PATH_SOURCE=$8
    local FIRMWARE_GIT=$9
    local FILE_pip_list=${10}
    local FILE_apt_base_board=${11}
    local FILE_apt_desktop_board=${12}
    local BOARD_MODEL=${13}
    local MODULES_ENABLE=${14}
    # 输出所有传入参数
    echo "TMP_rootfs_build=$TMP_rootfs_build"
    echo "FILE_base_rootfs=$FILE_base_rootfs"
    echo "ENTER_os_ver=$ENTER_os_ver"
    echo "FILE_apt_base=$FILE_apt_base"
    echo "FILE_apt_desktop=$FILE_apt_desktop"
    echo "ENTER_rootfs_type=$ENTER_rootfs_type"
    echo "PLACE_sf_list=$PLACE_sf_list"
    echo "PATH_SOURCE=$PATH_SOURCE"
    echo "FIRMWARE_GIT=$FIRMWARE_GIT"
    echo "FILE_pip_list=$FILE_pip_list"
    echo "FILE_apt_base_board=$FILE_apt_base_board"
    echo "FILE_apt_desktop_board=$FILE_apt_desktop_board"
    echo "BOARD_MODEL=$BOARD_MODEL"
    echo "MODULES_ENABLE=$MODULES_ENABLE"
    cleanup() {
        echo "Cleaning up..."
        if [[ -d $TMP_rootfs_build ]]; then
            run_status "umount $TMP_rootfs_build" umount_chroot $TMP_rootfs_build
        fi
        exit 1
    }
    trap cleanup SIGINT

    echo -e "\n\n------\t build rootfs \t------"

    # 准备基础rootfs
    _download_base_rootfs $FILE_base_rootfs $TMP_rootfs_build $ENTER_os_ver
    cp /usr/bin/qemu-aarch64-static ${TMP_rootfs_build}/usr/bin/
    chmod +x ${TMP_rootfs_build}/usr/bin/qemu-aarch64-static

    _apt_install_base_rootfs $TMP_rootfs_build $FILE_apt_base $FILE_apt_desktop $ENTER_rootfs_type $PLACE_sf_list $FILE_base_rootfs

    # 若主机通过hosts文件修改了apt域名指向，则在rootfs内也做相同的修改
    if grep -q "$APT_DOMAIN" /etc/hosts; then
        LINE=$(grep "$APT_DOMAIN" /etc/hosts)
        echo "$LINE" >>"$TMP_rootfs_build/etc/hosts"
    fi

    # wpi-update
    cd ${PATH_SOURCE}
    run_status "download wpi-update" clone_url "https://github.com/walnutpi/wpi-update.git"
    cp wpi-update/wpi-update ${TMP_rootfs_build}/usr/bin

    cd ${PATH_SOURCE}/wpi-update
    touch /tmp/walnutpi-board_model
    touch ${TMP_rootfs_build}/tmp/walnutpi-board_model
    echo -n "$BOARD_MODEL" >/tmp/walnutpi-board_model
    echo -n "$BOARD_MODEL" >${TMP_rootfs_build}/tmp/walnutpi-board_model
    VERSION_APT=$(echo $(./wpi-update -s | tail -n 1))

    # 创建release文件
    relseas_file="${TMP_rootfs_build}/etc/WalnutPi-release"
    # 如果存在文件relseas_file则删除
    if [ -f $relseas_file ]; then
        rm $relseas_file
    fi
    touch $relseas_file
    echo "version=${VERSION_APT}" >>$relseas_file
    echo "date=$(date "+%Y-%m-%d %H:%M")" >>$relseas_file
    echo "os_type=${ENTER_rootfs_type}" >>$relseas_file
    echo "" >>$relseas_file
    cat $relseas_file
    run_status "run wpi-update" chroot ${TMP_rootfs_build} /bin/bash -c "wpi-update"


    _pip_install "$TMP_rootfs_build" "$FILE_pip_list"
    _add_firmware "$PATH_SOURCE" "$FIRMWARE_GIT" "$TMP_rootfs_build"

    _wpi_install $TMP_rootfs_build $FILE_apt_base_board $FILE_apt_desktop_board $ENTER_rootfs_type $APT_DOMAIN

    # 设置要开机加载的驱动模块
    MODULES_LIST=$(echo ${MODULES_ENABLE} | tr ' ' '\n')
    echo "$MODULES_LIST" >${TMP_rootfs_build}/etc/modules

    cd $TMP_rootfs_build
    trap - SIGINT EXIT
}
