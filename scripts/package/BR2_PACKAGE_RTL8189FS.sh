#!/bin/bash

# 将编译后的ko模块输出到linux源码路径下
# 1 用于下载本包源码的路径
# 2 linux源码路径
# 3 交叉编译器路径
# 4 架构
PATH_SOURCE=$1
SOURCE_kernel=$2
CROSS_COMPILE=$3
ARCH=$4

echo "编译RTL8189FS驱动模块"
echo "PATH_SOURCE=$PATH_SOURCE"
echo "SOURCE_kernel=$SOURCE_kernel"
echo "CROSS_COMPILE=$CROSS_COMPILE"
echo "ARCH=$ARCH"

if [ "$ARCH" == "riscv64" ]; then
    ARCH="riscv"
fi

PACKAGE_PATH="${PATH_SOURCE}/rtl8189fs"
if [ ! -d "$PACKAGE_PATH" ]; then
    git clone https://github.com/jwrdegoede/rtl8189ES_linux.git "$PACKAGE_PATH"
    cd "$PACKAGE_PATH"
    git checkout 5d523593f41c0b8d723c6aa86b217ee1d0965786
fi

# 应用补丁：禁用CONFIG_CONCURRENT_MODE
# 检查第26行是否为目标行，如果是则替换
cd "$PACKAGE_PATH"
line_26=$(sed -n '26p' Makefile 2>/dev/null)
if [ "$line_26" = "EXTRA_CFLAGS += -DCONFIG_CONCURRENT_MODE" ]; then
    echo "应用禁用CONFIG_CONCURRENT_MODE的补丁..."
    if sed -i '26s/^EXTRA_CFLAGS += -DCONFIG_CONCURRENT_MODE$/# EXTRA_CFLAGS += -DCONFIG_CONCURRENT_MODE/' Makefile; then
        echo "补丁应用成功"
    else
        echo "警告：补丁应用失败"
        exit 1
    fi
else
    echo "第26行不是目标行或补丁已存在"
fi

cd "$PACKAGE_PATH"
make -C $SOURCE_kernel \
    ARCH=$ARCH \
    CROSS_COMPILE=$CROSS_COMPILE \
    M=$(pwd) \
    clean
make -C $SOURCE_kernel \
    ARCH=$ARCH \
    CROSS_COMPILE=$CROSS_COMPILE \
    M=$(pwd) \
    CONFIG_RTL8189FS=m \
    CONFIG_LITTLE_ENDIAN=m \
    CONFIG_RTW_DEBUG=n \
    modules -j$(nproc)
cp "$PACKAGE_PATH/8189fs.ko" "$SOURCE_kernel/"