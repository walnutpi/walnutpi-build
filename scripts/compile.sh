#!/bin/bash





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

    thread_count=$(grep -c ^processor /proc/cpuinfo)
    make $LINUX_CONFIG CROSS_COMPILE=$FILE_CROSS_COMPILE ARCH=${CHIP_ARCH}
    make -j$thread_count CROSS_COMPILE=$FILE_CROSS_COMPILE ARCH=${CHIP_ARCH}
    exit_if_last_error
    cp arch/${CHIP_ARCH}/boot/Image $PATH_OUTPUT
    
    echo "kernel compile success"

    run_status "export modules"     make  modules_install INSTALL_MOD_PATH="$PATH_OUTPUT" ARCH=${CHIP_ARCH}
    run_status "export device-tree" make dtbs_install INSTALL_DTBS_PATH="$PATH_OUTPUT/dtb" ARCH=${CHIP_ARCH}


    kernel_release_path="./include/config/kernel.release"
    kernel_version=$(head -n 1 "$kernel_release_path")
    # echo "Kernel version: $kernel_version"
    cp .config "${PATH_OUTPUT}/config-$kernel_version"

}

