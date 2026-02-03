#!/bin/bash
# 获取文件所在路径

_pack_as_boot_deb(){
    local path_package=$1
    local part_name=$2
    local package_desc=$3
    local BOARD_NAME=$4
    local SYTERKIT_BRANCH=$5
    local UBOOT_BRANCH=$6
    local ENTER_board_name=$7
    local OUTDIR_boot_package=$8
    local CHIP_ARCH=$9
    
    local package_name="$part_name-${BOARD_NAME}-${SYTERKIT_BRANCH}${UBOOT_BRANCH}"
    local control_file=$path_package/DEBIAN/control
    
    if [ ! -d $path_package/DEBIAN ];then
        mkdir -p $path_package/DEBIAN
    fi
    
    # 读取版本信息
    source ${ENTER_board_name}/config.txt
    local deb_version="$version"
    
    cd $path_package
    local size=$(du -sk --exclude=DEBIAN . | cut -f1)
    
    cat << EOF > $control_file
Package: ${package_name}
Description: ${package_desc}
Maintainer: walnutpi-build
Version: ${deb_version}
Section: free
Priority: optional
Installed-Size: ${size}
Architecture: ${CHIP_ARCH}
EOF
    local DEB_PACKAGE_NAME="${package_name}_${deb_version}_${CHIP_ARCH}.deb"
    echo "创建deb包 ${DEB_PACKAGE_NAME}"
    dpkg-deb -Zgzip -b "$path_package" "${OUTDIR_boot_package}/${DEB_PACKAGE_NAME}"
}

# 打包config.txt文件
# $1: PATH_TMP - 临时目录路径
# $2: ENTER_board_name - 板子配置目录路径
# $3: OUTDIR_boot_package - 输出目录
# $4: CHIP_ARCH - 芯片架构
pack_config_txt() {
    local PATH_TMP=$1
    local ENTER_board_name=$2
    local OUTDIR_boot_package=$3
    local CHIP_ARCH=$4
    
    local path_tmp_package_configtxt="${PATH_TMP}/boot-configtxt-$(basename ${ENTER_board_name})"
    if [ -d $path_tmp_package_configtxt ]; then
        rm -r $path_tmp_package_configtxt
    fi
    mkdir -p $path_tmp_package_configtxt
    
    local path_board_tmp_boot="/tmp-boot/boot-configtxt"
    local path_tmp_boot=${path_tmp_package_configtxt}${path_board_tmp_boot}
    mkdir -p $path_tmp_boot
    
    cp ${ENTER_board_name}/config.txt $path_tmp_boot
    
    local postinst_file=$path_tmp_package_configtxt/DEBIAN/postinst
    if [ ! -d $path_tmp_package_configtxt/DEBIAN ];then
        mkdir $path_tmp_package_configtxt/DEBIAN
    fi
    
    cp ${PATH_ASSET}/config-txt-postinst.sh $postinst_file
    chmod 755 $postinst_file
    
    source ${ENTER_board_name}/config.txt
    local BOARD_NAME_VAR="$BOARD_NAME"
    local SYTERKIT_BRANCH_VAR="$SYTERKIT_BRANCH"
    local UBOOT_BRANCH_VAR="$UBOOT_BRANCH"
    
    _pack_as_boot_deb $path_tmp_package_configtxt "configtxt" "config.txt for boot" \
        "$BOARD_NAME_VAR" "$SYTERKIT_BRANCH_VAR" "$UBOOT_BRANCH_VAR" \
        "$ENTER_board_name" "$OUTDIR_boot_package" "$CHIP_ARCH"
}


pack_boot_bin() {
    local PATH_TMP=$1
    local ENTER_board_name=$2
    local OUTFILE_boot_path=$3
    local PATH_save_boot_files=$4
    local OUTDIR_boot_package=$5
    local CHIP_ARCH=$6
    
    local path_tmp_package_configtxt="${PATH_TMP}/boot-bin-$(basename ${ENTER_board_name})"
    if [ -d $path_tmp_package_configtxt ]; then
        rm -r $path_tmp_package_configtxt
    fi
    mkdir -p $path_tmp_package_configtxt
    
    local path_board_tmp_boot="/tmp-boot/boot"
    local path_tmp_boot=${path_tmp_package_configtxt}${path_board_tmp_boot}
    mkdir -p $path_tmp_boot
    
    # 复制文件(如果存在)
    [ -f "${ENTER_board_name}/boot.cmd" ] && cp ${ENTER_board_name}/boot.cmd $path_tmp_boot
    [ -f "${ENTER_board_name}/boot.scr" ] && cp ${ENTER_board_name}/boot.scr $path_tmp_boot
    [ -d "${OUTFILE_boot_path}" ] && cp ${OUTFILE_boot_path}/*.bin $path_tmp_boot
    
    # 装入本项目保存的要放在boot文件夹内的文件
    if [ -d $PATH_save_boot_files ]; then
        cp -r $PATH_save_boot_files/* $path_tmp_boot
    fi
    
    local postinst_file=$path_tmp_package_configtxt/DEBIAN/postinst
    mkdir -p $path_tmp_package_configtxt/DEBIAN
    
    cp ${PATH_ASSET}/boot-postinst.sh $postinst_file
    chmod 755 $postinst_file
    
    # 从config.txt中读取BOARD_NAME, SYTERKIT_BRANCH, UBOOT_BRANCH
    source ${ENTER_board_name}/config.txt
    local BOARD_NAME_VAR="$BOARD_NAME"
    local SYTERKIT_BRANCH_VAR="$SYTERKIT_BRANCH"
    local UBOOT_BRANCH_VAR="$UBOOT_BRANCH"
    
    _pack_as_boot_deb $path_tmp_package_configtxt "bootbin" "the boot bin" \
        "$BOARD_NAME_VAR" "$SYTERKIT_BRANCH_VAR" "$UBOOT_BRANCH_VAR" \
        "$ENTER_board_name" "$OUTDIR_boot_package" "$CHIP_ARCH"
}

# 打包boot相关的deb包
# 参数说明:
# $1: PATH_TMP - 临时目录路径
# $2: ENTER_board_name - 板子配置目录路径
# $3: OUTFILE_boot_path - 板子输出路径
# $4: PATH_save_boot_files - 保存的boot文件目录
# $5: OUTDIR_boot_package - 输出目录
# $6: CHIP_ARCH - 芯片架构
pack_boot_deb(){
    local PATH_TMP=$1
    local ENTER_board_name=$2
    local OUTFILE_boot_path=$3
    local PATH_save_boot_files=$4
    local OUTDIR_boot_package=$5
    local CHIP_ARCH=$6
    
    pack_config_txt "$PATH_TMP" "$ENTER_board_name" "$OUTDIR_boot_package" "$CHIP_ARCH"
    pack_boot_bin "$PATH_TMP" "$ENTER_board_name" "$OUTFILE_boot_path" "$PATH_save_boot_files" "$OUTDIR_boot_package" "$CHIP_ARCH"
}