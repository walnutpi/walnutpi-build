#!/bin/bash

FILE_BEFOR_ROOTFS="befor_rootfs.sh"
FILE_BOARD_BEFOR_ROOTFS="${DIR_BOARD}/${FILE_BEFOR_ROOTFS}"

OPT_OS_VER=""
OPT_ROOTFS_TYPE=""
PATH_ROOTFS=""
FILE_ROOTFS_TAR=""

choose_rootfs() {
    # 只测试了bookworm的软件兼容性问题，有些库不确定能不能在旧版debian上运行
    # titlestr="Choose an version"
    # options+=("bookworm"    "debian 12(bookworm)")
    # options+=("bullseye"    "debian 11(bullseye)")
    # options+=("buster"  "debian 10(buster)")
    # OPT_OS_VER=$(whiptail --title "${titlestr}" --backtitle "${backtitle}" --notags \
    #             --menu "${menustr}" "${TTY_Y}" "${TTY_X}" $((TTY_Y - 8))  \
    #             --cancel-button Exit --ok-button Select "${options[@]}" \
    #             3>&1 1>&2 2>&3)
    # unset options
    # echo ${OPT_OS_VER}
    # [[ -z ${OPT_OS_VER} ]] && exit
    
    
    OPT_OS_VER="bookworm"
    
    titlestr="Server or Graphics"
    options+=("server"    "server")
    options+=("desktop"    "desktop")
    OPT_ROOTFS_TYPE=$(whiptail --title "${titlestr}" --backtitle "${backtitle}" --notags \
        --menu "${menustr}" "${TTY_Y}" "${TTY_X}" $((TTY_Y - 8))  \
        --cancel-button Exit --ok-button Select "${options[@]}" \
    3>&1 1>&2 2>&3)
    unset options
    echo $OPT_ROOTFS_TYPE
    [[ -z $OPT_ROOTFS_TYPE ]] && exit
    
    FILE_ROOTFS_TAR="${PATH_OUTPUT}/rootfs_${CHIP_NAME}_${OPT_OS_VER}_${OPT_ROOTFS_TYPE}.tar.gz"
    PATH_ROOTFS=${PATH_TMP}/${CHIP_NAME}_${OPT_OS_VER}_${OPT_ROOTFS_TYPE}
    
    # titlestr="Choose  Language"
    # options+=("cn"    "Chinese")
    # options+=("en"    "English")
    # OPT_LANGUAGE=$(whiptail --title "${titlestr}" --backtitle "${backtitle}" --notags \
    #             --menu "${menustr}" "${TTY_Y}" "${TTY_X}" $((TTY_Y - 8))  \
    #             --cancel-button Exit --ok-button Select "${options[@]}" \
    #             3>&1 1>&2 2>&3)
    # unset options
    # echo $OPT_LANGUAGE
    # [[ -z $OPT_LANGUAGE ]] && exit
    
}

generate_tmp_rootfs() {
    # set -e
    PATH_SAVE_ROOTFS=${PATH_SOURCE}/${OPT_OS_VER}_${CHIP_ARCH}_${OPT_ROOTFS_TYPE}
    FILE_SAVE_ROOTFS=${PATH_SAVE_ROOTFS}.tar
    if [[ -d $PATH_ROOTFS ]]; then
        run_as_client umount_chroot $PATH_ROOTFS
        rm -r ${PATH_ROOTFS}
    fi
    mkdir ${PATH_ROOTFS}
    
    echo -e "\n\n------\t build rootfs \t------"
    
    # 为节省编译时间，第一次编译时会构建一个基本rootfs，并安装base的软件
    PATH_SAVE_ROOTFS=${PATH_SOURCE}/${OPT_OS_VER}_${CHIP_ARCH}_${OPT_ROOTFS_TYPE}
    if [[ -f $FILE_SAVE_ROOTFS ]]; then
        run_status "unzip last rootfs"  tar -xvf $FILE_SAVE_ROOTFS -C  $PATH_ROOTFS
    else
        run_as_client mkdir ${PATH_ROOTFS} -p
        if [[ $(curl -s ipinfo.io/country) =~ ^(CN|HK)$ ]]; then
            debootstrap --foreign --verbose  --arch=${CHIP_ARCH} ${OPT_OS_VER} ${PATH_ROOTFS}  http://mirrors.tuna.tsinghua.edu.cn/debian/
        else
            debootstrap --foreign --verbose  --arch=${CHIP_ARCH} ${OPT_OS_VER} ${PATH_ROOTFS}  http://ftp.cn.debian.org/debian/
            
        fi
        
        exit_if_last_error
        
        qemu_arch=""
        case "${CHIP_ARCH}" in
            "arm64")
                qemu_arch="aarch64"
            ;;
            "arm")
                qemu_arch="arm"
            ;;
        esac
        cp /usr/bin/qemu-${qemu_arch}-static ${PATH_ROOTFS}/usr/bin/
        chmod +x ${PATH_ROOTFS}/usr/bin/qemu-${qemu_arch}-static
        
        # 完成rootfs的初始化
        cd ${PATH_ROOTFS}
        mount_chroot $PATH_ROOTFS
        LC_ALL=C LANGUAGE=C LANG=C chroot ${PATH_ROOTFS} /debootstrap/debootstrap --second-stage –verbose
        exit_if_last_error
        run_client_when_successfuly chroot $PATH_ROOTFS /bin/bash -c "DEBIAN_FRONTEND=noninteractive  apt-get clean"
        umount_chroot $PATH_ROOTFS
        
        tar -czf $FILE_SAVE_ROOTFS ./
    fi
    
    
    # 这个文件内存放安装过的软件的列表
    SF_LIST="${PATH_ROOTFS}/etc/release-apt"
    if [[ ! -f $SF_LIST ]]; then
        touch $SF_LIST
    fi
    
    
    # apt安装通用软件
    # cd $PATH_ROOTFS
    mount_chroot $PATH_ROOTFS
    
    run_status "apt update" chroot ${PATH_ROOTFS} /bin/bash -c "apt-get update"
    
    # 获取要本脚本的软件安装列表
    mapfile -t packages_build < <(grep -vE '^#|^$' ${FILE_APT_BASE})
    if [[ ${OPT_ROOTFS_TYPE} == "desktop" ]]; then
        mapfile -t desktop_packages  < <(grep -vE '^#|^$' ${FILE_APT_DESKTOP})
        packages_build=("${packages_build[@]}" "${desktop_packages[@]}")
    fi
    
    # 获取rootfs内的软件安装列表
    mapfile -t packages_rootfs < <(grep -vE '^#|^$' ${SF_LIST})
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
        run_status "apt install [$((i+1))/${total}] : $package " chroot $PATH_ROOTFS /bin/bash -c "DEBIAN_FRONTEND=noninteractive  apt-get install -y  ${package}"
    done
    total=${#packages_remove[@]}
    for (( i=0; i<${total}; i++ )); do
        package=${packages_remove[$i]}
        run_status "apt remove [$((i+1))/${total}] : $package " chroot $PATH_ROOTFS /bin/bash -c "DEBIAN_FRONTEND=noninteractive  apt-get remove -y  ${package}"
    done
    run_client_when_successfuly chroot $PATH_ROOTFS /bin/bash -c "DEBIAN_FRONTEND=noninteractive  apt-get clean"
    
    # 将安装过的软件名称，都写进文件内
    if [[  -f $SF_LIST ]]; then
        rm $SF_LIST
    fi
    touch $SF_LIST
    for package in "${packages_build[@]}"; do
        echo "$package" >> $SF_LIST
    done
    
    umount_chroot $PATH_ROOTFS
    # rsync -a $PATH_ROOTFS/ $PATH_SAVE_ROOTFS
    # 如果本次对保存的rootfs的apt软件有增删，则重设压缩包
    if [ ${#packages_install[@]} -gt 0 ] || [ ${#packages_remove[@]} -gt 0 ]; then
        rm -r $FILE_SAVE_ROOTFS
        cd ${PATH_ROOTFS}
        run_status "create the tar to save now rootfs" tar -czf $FILE_SAVE_ROOTFS ./
    fi
    
    
    # 运行板子自带的脚本
    if [ -f $FILE_BOARD_BEFOR_ROOTFS ]; then
        cp $FILE_BOARD_BEFOR_ROOTFS  ${PATH_ROOTFS}/opt/${FILE_BEFOR_ROOTFS}
        run_status "run ${FILE_BEFOR_ROOTFS}" chroot $PATH_ROOTFS /bin/bash -c "DEBIAN_FRONTEND=noninteractive  bash /opt/${FILE_BEFOR_ROOTFS}"
        rm ${PATH_ROOTFS}/opt/${FILE_BEFOR_ROOTFS}
    fi
    
    cd ${PATH_SOURCE}/wpi-update
    # run_status "get wpi-update version"
    VERSION_APT=$(echo $(./wpi-update -s | tail -n 1 ))
    
    # 创建release文件
    relseas_file="${PATH_ROOTFS}/etc/WalnutPi-release"
    touch $relseas_file
    echo "version=${VERSION_APT}" >> $relseas_file
    echo "date=$(date "+%Y-%m-%d %H:%M")" >> $relseas_file
    echo "os_type=${OPT_ROOTFS_TYPE}"  >> $relseas_file
    echo ""   >> $relseas_file

    # echo "kernel_git=$LINUX_GIT"  >> $relseas_file
    # echo "kernel_version=$LINUX_BRANCH"  >> $relseas_file
    # echo "kernel_config=$LINUX_CONFIG"  >> $relseas_file
    # echo "toolchain=$TOOLCHAIN_FILE_NAME"  >> $relseas_file
    
    cat $relseas_file
    
    
    # pip 安装指定软件
    # 删除一个用于禁止pip安装的文件 如在debian12中是/usr/lib/python3.11/EXTERNALLY-MANAGED
    LIB_DIR="${PATH_ROOTFS}/usr/lib"
    FILE_NAME="EXTERNALLY-MANAGED"
    find $LIB_DIR -type f -name "$FILE_NAME"  -delete
    mapfile -t packages < <(grep -vE '^#|^$' ${FILE_PIP_LIST})
    total=${#packages[@]}
    for (( i=0; i<${total}; i++ )); do
        package=${packages[$i]}
        # echo "pip3 [$((i+1))/${total}] : $package"
        run_status "pip3 [$((i+1))/${total}] : $package" chroot $PATH_ROOTFS /bin/bash -c "DEBIAN_FRONTEND=noninteractive  pip3 --no-cache-dir install   ${package}"
    done
    
    
    
    # firmware
    cd ${PATH_SOURCE}
    firm_dir=$(basename "${FIRMWARE_GIT}" .git)
    if [ -n "${FIRMWARE_GIT}" ]; then
        if [[ ! -d "firmware" ]]; then
            run_status "download firmware" git clone "${FIRMWARE_GIT}"
        fi
        cp -r ${firm_dir}/* ${PATH_ROOTFS}/lib/firmware
    fi
    
    # wpi-update
    cd ${PATH_SOURCE}
    run_status "download wpi-update" clone_url "https://github.com/walnutpi/wpi-update.git"
    cp wpi-update/wpi-update ${PATH_ROOTFS}/usr/bin
    
    run_status "run wpi-update" chroot ${PATH_ROOTFS} /bin/bash -c "wpi-update"
    
    # 安装kernel产生的的deb包
    cp ${PATH_KERNEL_PACKAGE}/*.deb  ${PATH_ROOTFS}/opt/
    cd ${PATH_ROOTFS}/opt/
    deb_packages=(*.deb)
    
    total=${#deb_packages[@]}
    for (( i=0; i<$total; i++ )); do
        deb_package=${deb_packages[$i]}
        run_status "kernel package [$((i+1))/${total}] : ${deb_package} " chroot ${PATH_ROOTFS} /bin/bash -c "dpkg -i /opt/${deb_package}"
        rm ${PATH_ROOTFS}/opt/${deb_package}
    done
    
    MODULES_LIST=$(echo ${MODULES_ENABLE} | tr ' ' '\n')
    echo "$MODULES_LIST" > ${PATH_ROOTFS}/etc/modules
    
    
    # apt安装各板指定软件
    mount_chroot $PATH_ROOTFS
    # 插入walnutpi的apt源
    echo $APT_SOURCES_TMP >> ${PATH_ROOTFS}/etc/apt/sources.list
    run_status "apt update" chroot ${PATH_ROOTFS} /bin/bash -c "apt-get update"
    
    mapfile -t packages < <(grep -vE '^#|^$' ${FILE_APT_BASE_BOARD})
    if [[ ${OPT_ROOTFS_TYPE} == "desktop" ]]; then
        mapfile -t desktop_packages  < <(grep -vE '^#|^$' ${FILE_APT_DESKTOP_BOARD})
        packages=("${packages[@]}" "${desktop_packages[@]}")
    fi
    total=${#packages[@]}
    for (( i=0; i<${total}; i++ )); do
        package=${packages[$i]}
        run_status "apt [$((i+1))/${total}] : $package " chroot $PATH_ROOTFS /bin/bash -c "DEBIAN_FRONTEND=noninteractive  apt-get -o Dpkg::Options::='--force-overwrite' install -y ${package}"
    done
    
    # 去除残余
    run_client_when_successfuly chroot $PATH_ROOTFS /bin/bash -c "DEBIAN_FRONTEND=noninteractive  apt-get clean"
    # sed -i "/${APT_SOURCES_TMP}/d" ${PATH_ROOTFS}/etc/apt/sources.list
    sed -i '$ d' ${PATH_ROOTFS}/etc/apt/sources.list
    
    cd $PATH_ROOTFS
    umount_chroot $PATH_ROOTFS
    if [ -f "$FILE_ROOTFS_TAR" ]; then
        rm $FILE_ROOTFS_TAR
    fi
    
    
    

    # run_status "create tar"  tar -czf $FILE_ROOTFS_TAR ./
    # rm -r $PATH_ROOTFS
}

pack_rootfs() {
    cd ${PATH_ROOTFS}
    run_status "create tar" tar -c -I 'xz -T0' -f $FILE_ROOTFS_TAR ./
}