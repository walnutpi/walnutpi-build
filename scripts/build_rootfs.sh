#!/bin/bash


APT_SOURCES_WALNUTPI="deb [trusted=yes] http://apt.walnutpi.com/debian/ bookworm main"
APT_DOMAIN="apt.walnutpi.com"
DEBIAN_BASE_URL="http://mirrors.tuna.tsinghua.edu.cn/debian/"
UBUNTU22_BASE_URL="https://mirror.tuna.tsinghua.edu.cn/ubuntu-cdimage/ubuntu-base/releases/22.04/release/ubuntu-base-22.04.4-base-arm64.tar.gz"
UBUNTU24_BASE_URL="https://mirror.tuna.tsinghua.edu.cn/ubuntu-cdimage/ubuntu-base/releases/24.04/release/ubuntu-base-24.04.2-base-arm64.tar.gz"

download_ubuntu_base() {
    local base_url=$1
    local tmp_file_name=$2
    local tmp_dir=$3
    wget $base_url -O $tmp_file_name
    run_status "unzip rootfs"  tar -xvf $tmp_file_name -C  $TMP_rootfs_build
    
    # base默认没写dns服务器
    local FILE="${TMP_rootfs_build}/etc/resolv.conf"
    local LINE="nameserver 8.8.8.8"
    grep -qF -- "$LINE" "$FILE" || echo "$LINE" >> "$FILE"
}

download_debian_base() {
    local base_url=$1
    local debian_name=$2
    local tmp_dir=$3
    
    debootstrap --foreign --verbose  --arch=${CHIP_ARCH} bookworm ${tmp_dir} $base_url
    exit_if_last_error
    
    # 完成rootfs的初始化
    cd ${tmp_dir}
    mount_chroot $tmp_dir
    LC_ALL=C LANGUAGE=C LANG=C chroot ${tmp_dir} /debootstrap/debootstrap --second-stage –verbose
    exit_if_last_error
    run_slient_when_successfuly chroot $tmp_dir /bin/bash -c "DEBIAN_FRONTEND=noninteractive  apt-get clean"
    umount_chroot $tmp_dir
}

generate_tmp_rootfs() {
    cleanup() {
        echo "Cleaning up..."
        if [[ -d $TMP_rootfs_build ]]; then
            run_status "umount $TMP_rootfs_build" umount_chroot $TMP_rootfs_build
        fi
        exit 1
    }
    trap cleanup SIGINT
    # set -e
    if [[ -d $TMP_rootfs_build ]]; then
        run_as_silent umount_chroot $TMP_rootfs_build
        rm -r ${TMP_rootfs_build}
    fi
    mkdir ${TMP_rootfs_build}
    
    echo -e "\n\n------\t build rootfs \t------"
    
    # 为节省编译时间，第一次编译时会构建一个基本rootfs，并安装base的软件，后续不再从头构建，直接从压缩包中解压出rootfs
    if [[ -f $FILE_base_rootfs ]]; then
        run_status "unzip last rootfs"  tar -xvf $FILE_base_rootfs -C  $TMP_rootfs_build
    else
        
        run_as_silent mkdir ${TMP_rootfs_build} -p
        case "${ENTER_os_ver}" in
            "${OPT_os_debian12}" | "$OPT_os_debian12_burn")
                download_debian_base $DEBIAN_BASE_URL "bookworm" $TMP_rootfs_build
            ;;
            
            "${OPT_os_ubuntu22}" )
                download_ubuntu_base $UBUNTU22_BASE_URL $FILE_base_rootfs $TMP_rootfs_build
            ;;
            
            "${OPT_os_ubuntu24}" )
                download_ubuntu_base $UBUNTU22_BASE_URL $FILE_base_rootfs $TMP_rootfs_build
            ;;
            
        esac
        cp /usr/bin/qemu-aarch64-static ${TMP_rootfs_build}/usr/bin/
        chmod +x ${TMP_rootfs_build}/usr/bin/qemu-aarch64-static
        
        cd $TMP_rootfs_build
        tar -czf $FILE_base_rootfs ./
        
        
    fi
    
    # 用这个文件作为安装过的软件的列表，在重复构建时节省时间
    if [[ ! -f $PLACE_sf_list ]]; then
        touch $PLACE_sf_list
    fi
    
    
    # apt安装通用软件
    # cd $TMP_rootfs_build
    mount_chroot $TMP_rootfs_build
    
    run_status "apt update" chroot ${TMP_rootfs_build} /bin/bash -c "apt-get update"
    
    # 获取要本脚本的软件安装列表
    mapfile -t packages_build < <(grep -vE '^#|^$' ${FILE_apt_base})
    if [[ ${ENTER_rootfs_type} == "desktop" ]]; then
        mapfile -t desktop_packages  < <(grep -vE '^#|^$' ${FILE_apt_desktop})
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
    for (( i=0; i<${total}; i++ )); do
        package=${packages_install[$i]}
        run_status "apt install [$((i+1))/${total}] : $package " chroot $TMP_rootfs_build /bin/bash -c "DEBIAN_FRONTEND=noninteractive  apt-get install -y  ${package}"
    done
    total=${#packages_remove[@]}
    for (( i=0; i<${total}; i++ )); do
        package=${packages_remove[$i]}
        run_status "apt remove [$((i+1))/${total}] : $package " chroot $TMP_rootfs_build /bin/bash -c "DEBIAN_FRONTEND=noninteractive  apt-get remove -y  ${package}"
    done
    run_slient_when_successfuly chroot $TMP_rootfs_build /bin/bash -c "DEBIAN_FRONTEND=noninteractive  apt-get clean"
    
    # 将安装过的软件名称，都写进文件内
    if [[  -f $PLACE_sf_list ]]; then
        rm $PLACE_sf_list
    fi
    touch $PLACE_sf_list
    for package in "${packages_build[@]}"; do
        echo "$package" >> $PLACE_sf_list
    done
    
    umount_chroot $TMP_rootfs_build
    # 如果本次对保存的rootfs的apt软件有增删，则重设压缩包
    if [ ${#packages_install[@]} -gt 0 ] || [ ${#packages_remove[@]} -gt 0 ]; then
        rm -r $FILE_base_rootfs
        cd ${TMP_rootfs_build}
        run_status "create the tar to save now rootfs" tar -czf $FILE_base_rootfs ./
    fi
    
    cd ${PATH_SOURCE}
    run_status "download wpi-update" clone_url "https://github.com/walnutpi/wpi-update.git"
    cd ${PATH_SOURCE}/wpi-update
    # run_status "get wpi-update version"
    touch /tmp/walnutpi-board_model
    touch ${TMP_rootfs_build}/tmp/walnutpi-board_model
    echo -n "$BOARD_MODEL" > /tmp/walnutpi-board_model
    echo -n "$BOARD_MODEL" > ${TMP_rootfs_build}/tmp/walnutpi-board_model
    VERSION_APT=$(echo $(./wpi-update -s | tail -n 1 ))
    
    # 创建release文件
    relseas_file="${TMP_rootfs_build}/etc/WalnutPi-release"
    touch $relseas_file
    echo "version=${VERSION_APT}" >> $relseas_file
    echo "date=$(date "+%Y-%m-%d %H:%M")" >> $relseas_file
    echo "os_type=${ENTER_rootfs_type}"  >> $relseas_file
    echo ""   >> $relseas_file
    
    # echo "kernel_git=$LINUX_GIT"  >> $relseas_file
    # echo "kernel_version=$LINUX_BRANCH"  >> $relseas_file
    # echo "kernel_config=$LINUX_CONFIG"  >> $relseas_file
    # echo "toolchain=$TOOLCHAIN_FILE_NAME"  >> $relseas_file
    
    cat $relseas_file
    
    
    # pip 安装指定软件
    LIB_DIR="${TMP_rootfs_build}/usr/lib"
    FILE_NAME="EXTERNALLY-MANAGED"
    find $LIB_DIR -type f -name "$FILE_NAME"  -delete
    
    if [ -f $FILE_pip_list ]; then
        mapfile -t packages < <(grep -vE '^#|^$' ${FILE_pip_list})
        total=${#packages[@]}
        for (( i=0; i<${total}; i++ )); do
            package=${packages[$i]}
            # echo "pip3 [$((i+1))/${total}] : $package"
            run_status "pip3 [$((i+1))/${total}] : $package" chroot $TMP_rootfs_build /bin/bash -c "DEBIAN_FRONTEND=noninteractive  pip3 --no-cache-dir install   ${package}"
        done
    fi
    
    
    
    # firmware
    cd ${PATH_SOURCE}
    firm_dir=$(basename "${FIRMWARE_GIT}" .git)
    
    if [ -n "${FIRMWARE_GIT}" ]; then
        if [[ ! -d "firmware" ]]; then
            run_status "download firmware" git clone "${FIRMWARE_GIT}"
        fi
        FIRMWARE_PATH="${TMP_rootfs_build}/lib/firmware"
        if [ ! -d $FIRMWARE_PATH ]; then
            mkdir -p $FIRMWARE_PATH
        fi
        cp -r ${firm_dir}/* $FIRMWARE_PATH
    fi
    
    # 若主机通过hosts文件修改了apt域名指向，则在rootfs内也做相同的修改
    if grep -q "$APT_DOMAIN" /etc/hosts; then
        LINE=$(grep "$APT_DOMAIN" /etc/hosts)
        echo "$LINE" >> "$TMP_rootfs_build/etc/hosts"
    fi
    # run_status "change hosts" chroot $TMP_rootfs_build /bin/bash -c "service network-manager restart"
    
    # wpi-update
    cp wpi-update/wpi-update ${TMP_rootfs_build}/usr/bin
    run_status "run wpi-update" chroot ${TMP_rootfs_build} /bin/bash -c "wpi-update"
    
    
    MODULES_LIST=$(echo ${MODULES_ENABLE} | tr ' ' '\n')
    echo "$MODULES_LIST" > ${TMP_rootfs_build}/etc/modules
    
    
    # apt安装各板指定软件
    mount_chroot $TMP_rootfs_build
    # 插入walnutpi的apt源
    echo $APT_SOURCES_WALNUTPI >> ${TMP_rootfs_build}/etc/apt/sources.list.d/walnutpi.list
    run_status "apt update" chroot ${TMP_rootfs_build} /bin/bash -c "apt-get update"
    
    mapfile -t packages < <(grep -vE '^#|^$' ${FILE_apt_base_board})
    if [[ ${ENTER_rootfs_type} == "desktop" ]]; then
        mapfile -t desktop_packages  < <(grep -vE '^#|^$' ${FILE_apt_desktop_board})
        packages=("${packages[@]}" "${desktop_packages[@]}")
    fi
    total=${#packages[@]}
    for (( i=0; i<${total}; i++ )); do
        package=${packages[$i]}
        run_status "apt [$((i+1))/${total}] : $package " chroot $TMP_rootfs_build /bin/bash -c "DEBIAN_FRONTEND=noninteractive  apt-get -o Dpkg::Options::='--force-overwrite' install -y ${package}"
    done
    
    # 删除插入hosts文件的内容
    if grep -q "$APT_DOMAIN" "$TMP_rootfs_build/etc/hosts"; then
        sed -i "/$APT_DOMAIN/d" "$TMP_rootfs_build/etc/hosts"
    fi
    
    # 去除残余
    run_slient_when_successfuly chroot $TMP_rootfs_build /bin/bash -c "DEBIAN_FRONTEND=noninteractive  apt-get clean"
    # sed -i '$ d' ${TMP_rootfs_build}/etc/apt/sources.list
    rm ${TMP_rootfs_build}/etc/apt/sources.list.d/walnutpi.list
    
    
    cd $TMP_rootfs_build
    umount_chroot $TMP_rootfs_build
    trap - SIGINT EXIT
}
add_file_to_tmp_rootfs() {
    local source_file=$1
    local dest_path=$2
    if [[ -f "$source_file" ]]; then
        if [[ -d "$dest_path" ]]; then
            rm -r "$dest_path"
        fi
        mkdir -p "$dest_path"
        run_status "copy $(basename $source_file) to $dest_path" cp "$source_file" "$dest_path"
    fi
}

add_emmc_burn_file(){
    local source_file=$1
    add_file_to_tmp_rootfs ${source_file} "${TMP_rootfs_build}/opt/burn"
}

pack_rootfs() {
    cd ${TMP_rootfs_build}
    if [ -f "$OUTFILE_rootfs_tar" ]; then
        rm $OUTFILE_rootfs_tar
    fi
    run_status "create tar" tar -c -I 'xz -T0' -f $OUTFILE_rootfs_tar ./
}