#!/bin/bash

OPT_OS_VER=""
OPT_ROOTFS_TYPE=""
# OPT_LANGUAGE=""
PATH_ROOTFS=""
FILE_ROOTFS_TAR=""


mount_chroot()
{
	local target=$1
	mount -t proc chproc "${target}"/proc
	mount -t sysfs chsys "${target}"/sys
	mount -t devtmpfs chdev "${target}"/dev || mount --bind /dev "${target}"/dev
	mount -t devpts chpts "${target}"/dev/pts
}

umount_chroot()
{
	local target=$1
	while grep -Eq "${target}.*(dev|proc|sys)" /proc/mounts
	do
		umount -l --recursive "${target}"/dev >/dev/null 2>&1
		umount -l "${target}"/proc >/dev/null 2>&1
		umount -l "${target}"/sys >/dev/null 2>&1
		sleep 5
	done
}

choose_rootfs() {

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

    FILE_ROOTFS_TAR="${PATH_OUTPUT}/rootfs_${OPT_OS_VER}_${OPT_ROOTFS_TYPE}.tar.gz"
    PATH_ROOTFS=${PATH_TMP}/${OPT_OS_VER}_${OPT_ROOTFS_TYPE}

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

create_rootfs() {
    
    run_as_client umount_chroot $PATH_ROOTFS
    rm -r ${PATH_ROOTFS}

    echo -e "\n\n------\t build rootfs \t------"

    PATH_SAVE_ROOTFS=${PATH_SOURCE}/${OPT_OS_VER}_${CHIP_ARCH}
    if [[ -d $PATH_SAVE_ROOTFS ]]; then
        cp -r $PATH_SAVE_ROOTFS $PATH_ROOTFS 
    else
        run_as_client mkdir ${PATH_ROOTFS} -p
        debootstrap --foreign --verbose  --arch=${CHIP_ARCH} ${OPT_OS_VER} ${PATH_ROOTFS}  http://mirrors.huaweicloud.com/debian/    
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
        # cd ${PATH_ROOTFS}
        umount_chroot $PATH_ROOTFS
        cp -r $PATH_ROOTFS $PATH_SAVE_ROOTFS
    fi


    cd $PATH_ROOTFS
    # sudo tar czpvf - . | split -d -b 80M - ../bookworm_arm64.tar
    # run_status_piped "unzip rootfs" "cat ${PATH_RESOURCE}/${OPT_OS_VER}_${CHIP_ARCH}.tar* | tar xzpvf - -C ${PATH_ROOTFS}"

    # exit_if_last_error

    mount_chroot $PATH_ROOTFS

    # apt安装指定软件
    PATH_APT_CACHE="${PATH_TMP}/apt_cache_${OPT_OS_VER}_${CHIP_ARCH}"
    if [ ! -d $PATH_APT_CACHE ]; then
        mkdir $PATH_APT_CACHE
    fi
    run_as_client cp -r ${PATH_APT_CACHE}/* ${PATH_ROOTFS}/var/cache/apt/archives/
    run_status "apt update" chroot ${PATH_ROOTFS} /bin/bash -c "apt-get update"

    while read -r package; do
        if [[ ${package} == \#* ]] || [[ -z ${package} ]]; then
            continue
        fi
        # echo ${package}
        run_status "install ${package}" chroot $PATH_ROOTFS /bin/bash -c "DEBIAN_FRONTEND=noninteractive  apt-get install -y  ${package}"
    done < ${FILE_APT_BASE}

    if [[ ${OPT_ROOTFS_TYPE} == "desktop" ]]; then
        while read -r package; do
            if [[ ${package} == \#* ]] || [[ -z ${package} ]]; then
                continue
            fi
            # echo ${package}
            run_status "install ${package}" chroot $PATH_ROOTFS /bin/bash -c "DEBIAN_FRONTEND=noninteractive apt-get install -y ${package}"
        done < ${FILE_APT_DESKTOP}
    fi

    run_as_client cp -r  ${PATH_ROOTFS}/var/cache/apt/archives/* ${PATH_APT_CACHE}/
    run_client_when_successfuly chroot $PATH_ROOTFS /bin/bash -c "DEBIAN_FRONTEND=noninteractive  apt-get clean"


    # pip 安装指定软件
    # 删除一个用于禁止pip安装的文件 如在debian12中是/usr/lib/python3.11/EXTERNALLY-MANAGED
    LIB_DIR="${PATH_ROOTFS}/usr/lib"
    FILE_NAME="EXTERNALLY-MANAGED"
    find $LIB_DIR -type f -name "$FILE_NAME"  -delete

    while read -r package; do
        if [[ ${package} == \#* ]] || [[ -z ${package} ]]; then
            continue
        fi
        # echo ${package}
        run_status "pip3 install\t${package}" chroot $PATH_ROOTFS /bin/bash -c "DEBIAN_FRONTEND=noninteractive  pip3 install --no-cache-dir  ${package}"
    done < ${FILE_PIP_LIST}



    # firmware
    cd ${PATH_SOURCE}
    firm_dir=$(basename "${FIRMWARE_GIT}" .git)
    if [ -n "${FIRMWARE_GIT}" ]; then
        run_as_client git clone "${FIRMWARE_GIT}"
        cp -r ${firm_dir}/* ${PATH_ROOTFS}/lib/firmware
    fi


    # 驱动
    if [ -d "${PATH_OUTPUT}" ]; then
        cp -r ${PATH_OUTPUT}/lib/* ${PATH_ROOTFS}/lib/
    fi


    # modules
    MODULES_LIST=$(echo ${MODULES_ENABLE} | tr ' ' '\n')
    echo "$MODULES_LIST" > ${PATH_ROOTFS}/etc/modules
    

    # 复制setting目录下的脚本进rootfs内执行
    shopt -s dotglob
    find $PATH_S_FS_BASE -type f -name "*.sh" -exec cp {} ${PATH_ROOTFS}/opt/ \;
    cp -r ${PATH_S_FS_BASE_RESOURCE}/. ${PATH_ROOTFS}/opt/
    
    find ${PATH_S_FS_USER}/ -type f -name "*.sh" -exec cp {} ${PATH_ROOTFS}/opt/ \;
    cp -r ${PATH_S_FS_USER_RESOURCE}/. ${PATH_ROOTFS}/opt/
    

    if [ "$OPT_ROOTFS_TYPE" = "desktop" ]; then
        find $PATH_S_FS_DESK -type f -name "*.sh" -exec cp {} ${PATH_ROOTFS}/opt/ \;
        cp -r ${PATH_S_FS_DESK_RESOURCE}/. ${PATH_ROOTFS}/opt/
    fi
    
    for file in $(find ${PATH_ROOTFS}/opt -type f -name "*.sh" | sort); do
        chmod +x $file
        file_name=$(basename "$file")
        # echo $file_name
        # chroot  $PATH_ROOTFS /bin/bash -c "export HOME=/root; cd /opt/ && ./${file_name}"
        run_status "running script \t${file_name}" chroot  $PATH_ROOTFS /bin/bash -c "export HOME=/root; cd /opt/ && ./${file_name}"
        rm $file
    done



    SYSTEMD_DIR="${PATH_ROOTFS}/lib/systemd/system/"
    WALNUTPI_DIR="${PATH_ROOTFS}/usr/lib/walnutpi"
    mkdir -p "$WALNUTPI_DIR"

    echo "service"

    # 启用通用service
    for file in "$PATH_SERVICE"/*; do
        # echo $file
        if [[ $file == *.service ]]; then
            cp $file $SYSTEMD_DIR
            run_status "enable service\t${file}" chroot ${PATH_ROOTFS} /bin/bash -c "systemctl enable  $(basename "$file" .service)"
        else
            cp "$file" "$WALNUTPI_DIR"
            chmod +x "${WALNUTPI_DIR}/$(basename $file)"
        fi
    done


    # 启用board自带service
    for file in ${CONF_DIR}/service/*.service; do
        echo $file
        cp $file $SYSTEMD_DIR
        run_status "enable service\t${file}" chroot ${PATH_ROOTFS} /bin/bash -c "systemctl enable  $(basename "$file" .service)"

    done      

    # 配置中文
    # if [ "$OPT_LANGUAGE" = "cn" ]; then
    #     echo "设置语言为中文"
    #     # FILE="${PATH_ROOTFS}/etc/locale.gen"
    #     # sed -i '/^# zh_CN.UTF-8/ s/^# //' $FILE
    #     # chroot $PATH_ROOTFS /bin/bash -c "DEBIAN_FRONTEND=noninteractive  locale-gen"

    #     # sed -i '$i\\localectl set-locale LANG=zh_CN.UTF-8' ${PATH_ROOTFS}/usr/lib/walnutpi/firstboot
    #     # chroot $PATH_ROOTFS /bin/bash -c "DEBIAN_FRONTEND=noninteractive  localectl set-locale LANG=zh_CN.UTF-8"
    # fi 

    echo "create tar"
    cd $PATH_ROOTFS
    umount_chroot $PATH_ROOTFS
    if [ -f "$FILE_ROOTFS_TAR" ]; then
        rm $FILE_ROOTFS_TAR
    fi
    
    run_client_when_successfuly tar -czf $FILE_ROOTFS_TAR ./
    # rm -r $PATH_ROOTFS

}