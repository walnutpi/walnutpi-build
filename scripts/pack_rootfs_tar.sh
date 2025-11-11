#!/bin/bash

# 参数说明:
# $1 - TMP_rootfs_build: 临时构建rootfs的目录
# $2 - OUTFILE_rootfs_tar: 输出的rootfs tar压缩包文件路径
pack_rootfs_tar() {
    local TMP_rootfs_build=$1
    local OUTFILE_rootfs_tar=$2
    echo "TMP_rootfs_build: $TMP_rootfs_build"
    echo "OUTFILE_rootfs_tar: $OUTFILE_rootfs_tar"
    cd ${TMP_rootfs_build}
    if [ -f "$OUTFILE_rootfs_tar" ]; then
        rm $OUTFILE_rootfs_tar
    fi
    run_status "create tar" tar -c -I 'xz -T0' -f $OUTFILE_rootfs_tar ./
}