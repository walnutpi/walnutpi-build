#!/bin/bash
# 参数说明:
# $1 - SOURCE_kernel: 内核源码路径
# $2 - LINUX_CONFIG: 内核配置文件名
# $3 - USE_CROSS_COMPILE: 交叉编译前缀
# $4 - CHIP_ARCH: 芯片架构
compile_kernel() {
    local SOURCE_kernel=$1
    local LINUX_CONFIG=$2
    local USE_CROSS_COMPILE=$3
    local CHIP_ARCH=$4
    # 输出所有参数
    echo "SOURCE_kernel=$SOURCE_kernel"
    echo "LINUX_CONFIG=$LINUX_CONFIG"
    echo "USE_CROSS_COMPILE=$USE_CROSS_COMPILE"
    echo "CHIP_ARCH=$CHIP_ARCH"

    if [ $CHIP_ARCH == "riscv64" ]; then
        CHIP_ARCH="riscv"
    fi
    
    cd $SOURCE_kernel
    if [ ! -f .scmversion ]; then
        touch .scmversion
    fi
    make $LINUX_CONFIG CROSS_COMPILE=$USE_CROSS_COMPILE ARCH=${CHIP_ARCH}
    make -j$(nproc) CROSS_COMPILE=$USE_CROSS_COMPILE ARCH=${CHIP_ARCH}

    if [ -d bsp/modules/gpu ]; then
        export srctree=$(pwd)
        make -j$(nproc) CROSS_COMPILE=$USE_CROSS_COMPILE ARCH=${CHIP_ARCH} -C bsp/modules/gpu M=bsp/modules/gpu
    fi
    exit_if_last_error
    echo "kernel compile success"
}
