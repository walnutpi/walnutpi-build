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

echo "编译AIC8800驱动模块"
echo "PATH_SOURCE=$PATH_SOURCE"
echo "SOURCE_kernel=$SOURCE_kernel"
echo "CROSS_COMPILE=$CROSS_COMPILE"
echo "ARCH=$ARCH"

if [ "$ARCH" == "riscv64" ]; then
    ARCH="riscv"
fi

PACKAGE_PATH="${PATH_SOURCE}/aic8800_sdio"
if [ ! -d "$PACKAGE_PATH" ]; then
    git clone https://github.com/walnutpi/aic8800_sdio.git "$PACKAGE_PATH"
    cd "$PACKAGE_PATH"
    git checkout e8ed136ff7c87675400118f4d4dfa54726c7aaa7
fi


cd "$PACKAGE_PATH/src"
# make -C $SOURCE_kernel \
#     ARCH=$ARCH \
#     CROSS_COMPILE=$CROSS_COMPILE \
#     M=$(pwd) \
#     clean
make -C $SOURCE_kernel \
    ARCH=$ARCH \
    CROSS_COMPILE=$CROSS_COMPILE \
    M=$(pwd) \
    CONFIG_WIRELESS=y \
    CONFIG_CFG80211=y \
    CONFIG_MAC80211=y \
    CONFIG_MMC=y \
    CONFIG_BT_HCIUART=y \
    CONFIG_BT_HCIUART_H4=y \
    CONFIG_BT_BNEP=y \
    CONFIG_BT_HIDP=y \
    CONFIG_BT_RFCOMM=y \
    CONFIG_BT_RFCOMM_TTY=y \
    modules -j$(nproc)

cp $PACKAGE_PATH/src/aic8800_bsp/aic8800_bsp.ko "$SOURCE_kernel/"
cp $PACKAGE_PATH/src/aic8800_fdrv/aic8800_fdrv.ko "$SOURCE_kernel/"
cp $PACKAGE_PATH/src/aic8800_btlpm/aic8800_btlpm.ko "$SOURCE_kernel/"