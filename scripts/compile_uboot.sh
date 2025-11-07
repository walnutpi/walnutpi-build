#!/bin/bash

# 编译 ARM Trusted Firmware
# 参数说明:
# $1: PATH_SOURCE - 源码路径
# $2: ATF_GIT - ATF Git 仓库地址
# $3: ATF_BRANCH - ATF 分支名
# $4: ATF_PLAT - ATF 平台配置
# $5: USE_CROSS_COMPILE - 交叉编译前缀
compile_atf() {
    local PATH_SOURCE=$1
    local ATF_GIT=$2
    local ATF_BRANCH=$3
    local ATF_PLAT=$4
    local USE_CROSS_COMPILE=$5

    # 输出所有传入参数的值
    echo "<atf> PATH_SOURCE: $PATH_SOURCE"
    echo "<atf> ATF_GIT: $ATF_GIT"
    echo "<atf> ATF_BRANCH: $ATF_BRANCH"
    echo "<atf> ATF_PLAT: $ATF_PLAT"
    echo "<atf> USE_CROSS_COMPILE: $USE_CROSS_COMPILE"
    
    cd $PATH_SOURCE
    echo $ATF_GIT
    local dirname="${PATH_SOURCE}/$(basename "$ATF_GIT" .git)"
    # 如果dirname路径不存在才clone
    if [ ! -d $dirname ]; then
        git clone $ATF_GIT
    fi
    cd $dirname
    git checkout $ATF_BRANCH
    run_as_user make PLAT=$ATF_PLAT DEBUG=1 bl31 CROSS_COMPILE=$USE_CROSS_COMPILE
    exit_if_last_error
}

# 编译 U-Boot
# $1: PATH_SOURCE - 源码路径
# $2: UBOOT_GIT - U-Boot Git 仓库地址
# $3: UBOOT_BRANCH - U-Boot 分支名
# $4: UBOOT_CONFIG - U-Boot 配置
# $5: USE_CROSS_COMPILE - 交叉编译前缀
# $6: UBOOT_BIN_NAME - U-Boot 二进制文件名
# $7: OUTFILE_boot_bin - 输出的 boot 二进制文件路径
# $8: ATF_PLAT - ATF 平台配置 (可选)
compile_uboot() {
    local PATH_SOURCE=$1
    local UBOOT_GIT=$2
    local UBOOT_BRANCH=$3
    local UBOOT_CONFIG=$4
    local USE_CROSS_COMPILE=$5
    local UBOOT_BIN_NAME=$6
    local OUTFILE_boot_bin=$7
    local ATF_PLAT=$8
    # 输出所有传入参数的值
    
    echo "<uboot> PATH_SOURCE: $PATH_SOURCE"
    echo "<uboot> UBOOT_GIT: $UBOOT_GIT"
    echo "<uboot> UBOOT_BRANCH: $UBOOT_BRANCH"
    echo "<uboot> UBOOT_CONFIG: $UBOOT_CONFIG"
    echo "<uboot> USE_CROSS_COMPILE: $USE_CROSS_COMPILE"
    echo "<uboot> UBOOT_BIN_NAME: $UBOOT_BIN_NAME"
    echo "<uboot> OUTFILE_boot_bin: $OUTFILE_boot_bin"
    echo "<uboot> ATF_PLAT: $ATF_PLAT"


    cd $PATH_SOURCE
    
    local dirname="${PATH_SOURCE}/$(basename "$UBOOT_GIT" .git)-$UBOOT_BRANCH"
    clone_branch $UBOOT_GIT $UBOOT_BRANCH $dirname
    cd $dirname
    
    run_as_user make $UBOOT_CONFIG
    
    # 如果提供了ATF_PLAT，则使用BL31参数编译，否则直接使用CROSS_COMPILE编译
    if [ -n "$ATF_PLAT" ]; then
        run_as_user make BL31=../arm-trusted-firmware/build/$ATF_PLAT/debug/bl31.bin \
        CROSS_COMPILE=$USE_CROSS_COMPILE
    else
        run_as_user make CROSS_COMPILE=$USE_CROSS_COMPILE
    fi
    
    exit_if_last_error
    cp $UBOOT_BIN_NAME $OUTFILE_boot_bin
}