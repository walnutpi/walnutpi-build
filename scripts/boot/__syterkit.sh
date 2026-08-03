#!/bin/bash

# 编译 Syterkit
# 参数说明:
# $1: PATH_SOURCE - 源码路径
# $2: SYTERKIT_GIT - Syterkit Git 仓库地址
# $3: SYTERKIT_BRANCH - Syterkit 分支名
# $4: SYTERKIT_BOARD_FILE - Syterkit 板级配置文件路径
# $5: SYTERKIT_OUT_BIN - Syterkit 输出的二进制文件名
# $6: OUTFILE_boot_bin - 最终输出的 boot 二进制文件路径
compile_syterkit() {
    local PATH_SOURCE=$1
    local SYTERKIT_GIT=$2
    local SYTERKIT_BRANCH=$3
    local SYTERKIT_BOARD_FILE=$4
    local SYTERKIT_OUT_BIN=$5
    local OUTFILE_boot_bin=$6
    
    echo "PATH_SOURCE: $PATH_SOURCE"
    echo "SYTERKIT_GIT: $SYTERKIT_GIT"
    echo "SYTERKIT_BRANCH: $SYTERKIT_BRANCH"
    echo "SYTERKIT_BOARD_FILE: $SYTERKIT_BOARD_FILE"
    echo "SYTERKIT_OUT_BIN: $SYTERKIT_OUT_BIN"
    echo "OUTFILE_boot_bin: $OUTFILE_boot_bin"

    cd $PATH_SOURCE
    local dirname="${PATH_SOURCE}/$(basename "$SYTERKIT_GIT" .git)-$SYTERKIT_BRANCH"
    clone_branch $SYTERKIT_GIT $SYTERKIT_BRANCH $dirname
    cd $dirname
    local workspace_name="build"
    create_dir $workspace_name
    cd $workspace_name
    run_as_user cmake -DCMAKE_BOARD_FILE=$SYTERKIT_BOARD_FILE ..
    exit_if_last_error
    run_as_user make
    exit_if_last_error
    cp $SYTERKIT_OUT_BIN $OUTFILE_boot_bin
}