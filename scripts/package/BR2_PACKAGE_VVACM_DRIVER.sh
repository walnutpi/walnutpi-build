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

echo "编译VVCAM驱动模块"
echo "PATH_SOURCE=$PATH_SOURCE"
echo "SOURCE_kernel=$SOURCE_kernel"
echo "CROSS_COMPILE=$CROSS_COMPILE"
echo "ARCH=$ARCH"

if [ "$ARCH" == "riscv64" ]; then
    ARCH="riscv"
fi

PACKAGE_PATH="${PATH_SOURCE}/vvcam-driver"
if [ ! -d "$PACKAGE_PATH" ]; then
    git clone https://github.com/walnutpi/vvcam-driver.git "$PACKAGE_PATH"
else
    cd "$PACKAGE_PATH"
    git config --global --add safe.directory "$PACKAGE_PATH"
    git checkout main
    git pull
fi
cd "$PACKAGE_PATH"
git checkout b22e3cd0ab0f1d5d1db8c1d30d128aa0ba44d277


cd "$PACKAGE_PATH"
# make -C $SOURCE_kernel \
#     ARCH=$ARCH \
#     CROSS_COMPILE=$CROSS_COMPILE \
#     M=$(pwd) \
#     clean
make -C $SOURCE_kernel \
    ARCH=$ARCH \
    CROSS_COMPILE=$CROSS_COMPILE \
    M=$(pwd) \
    CONFIG_RTL8189FS=m \
    CONFIG_LITTLE_ENDIAN=m \
    CONFIG_RTW_DEBUG=n \
    modules -j$(nproc)
cp $PACKAGE_PATH/*ko "$SOURCE_kernel/"
cp $PACKAGE_PATH/v4l2/isp/*ko "$SOURCE_kernel/"