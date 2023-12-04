#!/bin/bash
PACKAGE_NAME=kernel-${LINUX_BRANCH}-${CHIP_NAME}

DEB_NAME=${PACKAGE_NAME}_1.0.0_all.deb





clone_source() {
    url=$1
    dirname=$(basename "$url" .git)
    if [ ! -d "$dirname" ]; then
        echo "clone $dirname"
        run_as_client_try3 git clone $url
    fi
}

COMPILE_ATF() {
    cd $PATH_SOURCE
    echo $ATF_GIT
    clone_source $ATF_GIT
    dirname=$(basename "$ATF_GIT" .git)
    cd $dirname
    make PLAT=$ATF_PLAT  DEBUG=1 bl31 CROSS_COMPILE=$FILE_CROSS_COMPILE
    exit_if_last_error
}

compile_uboot() {
    if [ -n "$ATF_GIT" ]; then
        COMPILE_ATF
    fi
    cd $PATH_SOURCE
    clone_source $UBOOT_GIT
    dirname=$(basename "$UBOOT_GIT" .git)
    cd $dirname
    git checkout $UBOOT_BRANCH
    
    make $UBOOT_CONFIG
    make BL31=../arm-trusted-firmware/build/$ATF_PLAT/debug/bl31.bin \
    CROSS_COMPILE=$FILE_CROSS_COMPILE
    exit_if_last_error
    cp $UBOOT_BIN_NAME $PATH_OUTPUT
    
}


compile_kernel() {
    cd $PATH_SOURCE
    clone_source $LINUX_GIT
    
    dirname=$(basename "$LINUX_GIT" .git)
    cd $dirname
    git checkout $LINUX_BRANCH
    
    PATH_KERNEL=${PATH_SOURCE}/${dirname}
    
    thread_count=$(grep -c ^processor /proc/cpuinfo)
    make $LINUX_CONFIG CROSS_COMPILE=$FILE_CROSS_COMPILE ARCH=${CHIP_ARCH}
    make -j$thread_count CROSS_COMPILE=$FILE_CROSS_COMPILE ARCH=${CHIP_ARCH}
    exit_if_last_error
    
    
    echo "kernel compile success"
    
    # cp ${PATH_KERNEL}/arch/${CHIP_ARCH}/boot/Image $PATH_OUTPUT
    # run_status "export modules"     make  modules_install INSTALL_MOD_PATH="$PATH_OUTPUT" ARCH=${CHIP_ARCH}
    # run_status "export device-tree" make dtbs_install INSTALL_DTBS_PATH="$PATH_OUTPUT/dtb" ARCH=${CHIP_ARCH}
    
    TMP_DEB=${PATH_TMP}/kernel_${LINUX_CONFIG}_${LINUX_BRANCH}
    if [[ -d $TMP_DEB ]]; then
        rm -r $TMP_DEB
    fi
    mkdir -p  $TMP_DEB/boot
    
    run_status "export Image" cp ${PATH_KERNEL}/arch/${CHIP_ARCH}/boot/Image $TMP_DEB/boot/
    run_status "export modules" make  modules_install INSTALL_MOD_PATH="$TMP_DEB" ARCH=${CHIP_ARCH}
    run_status "export device-tree" make dtbs_install INSTALL_DTBS_PATH="$TMP_DEB/boot/" ARCH=${CHIP_ARCH}
    # 设备树导出后，可能会产生一个allwinner/.dtb的路径，把里面的dtb提取到外面
    folder_name=$(ls -d $TMP_DEB/boot/*/ | head -n 1)
    cp -r $folder_name* $TMP_DEB/boot/
    rm -r $folder_name
    if [[ -d $TMP_DEB/boot/overlay  ]]; then
        mv $TMP_DEB/boot/overlay $TMP_DEB/boot/overlays
    fi
    
    mkdir   $TMP_DEB/DEBIAN/
    cd $TMP_DEB
    size=$(du -sk --exclude=DEBIAN . | cut -f1)
    echo "size=$size"
    git_email=$(git config --global user.email)
    
    cd $PATH_KERNEL
    git_log=$(git log --oneline)
    commit_count=$(echo "$git_log" | wc -l)
    deb_version="1.$commit_count.0"
    DEB_NAME=${PACKAGE_NAME}_${deb_version}_all.deb
    
    
cat << EOF > $TMP_DEB/DEBIAN/control
Package: ${PACKAGE_NAME}
Description: linux kernel file
Maintainer: ${git_email}
Version: ${deb_version}
Section: free
Priority: optional
Installed-Size: ${size}
Architecture: all
EOF
    run_status "boot.scr" mkimage -C none -A arm -T script -d ${CONF_DIR}/boot.cmd ${CONF_DIR}/boot.scr
    cp ${CONF_DIR}/boot.cmd $TMP_DEB/boot
    cp ${CONF_DIR}/boot.scr $TMP_DEB/boot
    cp ${CONF_DIR}/config.txt $TMP_DEB/boot
    
    run_status "创建deb包 ${DEB_NAME} " dpkg -b "$TMP_DEB" "${PATH_OUTPUT}/${DEB_NAME}"
    
}

