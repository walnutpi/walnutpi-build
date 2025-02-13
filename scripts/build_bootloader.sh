#!/bin/bash




compile_atf() {
    cd $PATH_SOURCE
    echo $ATF_GIT
    git clone  $ATF_GIT
    dirname="${PATH_SOURCE}/$(basename "$ATF_GIT" .git)"
    cd $dirname
    git checkout $ATF_BRANCH
    run_as_user make PLAT=$ATF_PLAT  DEBUG=1 bl31 CROSS_COMPILE=$USE_CROSS_COMPILE
    exit_if_last_error
}

compile_uboot() {
    if [ -n "$ATF_GIT" ]; then
        compile_atf
    fi
    cd $PATH_SOURCE
    
    dirname="${PATH_SOURCE}/$(basename "$UBOOT_GIT" .git)-$UBOOT_BRANCH"
    clone_branch $UBOOT_GIT $UBOOT_BRANCH $dirname
    cd $dirname
    
    run_as_user make $UBOOT_CONFIG
    run_as_user make BL31=../arm-trusted-firmware/build/$ATF_PLAT/debug/bl31.bin \
    CROSS_COMPILE=$USE_CROSS_COMPILE
    exit_if_last_error
    cp $UBOOT_BIN_NAME $OUTFILE_boot_bin
    
}
compile_syterkit() {
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
get_config_txt_version() {
    source ${ENTER_board_name}/config.txt
    echo "$version"
}

# 填写control文件,生成deb包到输出路径
_pack_as_boot_deb(){
    local path_package=$1
    local part_name=$2
    local package_desc=$3
    
    local package_name="$part_name-${BOARD_NAME}-${SYTERKIT_BRANCH}${UBOOT_BRANCH}"
    control_file=$path_package/DEBIAN/control
    
    if [ ! -d $path_package/DEBIAN ];then
        mkdir -p $path_package/DEBIAN
    fi
    
    
    source ${ENTER_board_name}/config.txt
    deb_version="$version"
    
    cd $path_package
    size=$(du -sk --exclude=DEBIAN . | cut -f1)
    
    
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
    DEB_PACKAGE_NAME="${package_name}_${deb_version}_${CHIP_ARCH}.deb"
    run_status "创建deb包 ${DEB_PACKAGE_NAME} " dpkg -b "$path_package" "${OUTDIR_boot_package}/${DEB_PACKAGE_NAME}"
    
}

pack_config_txt() {
    local path_tmp_package_configtxt="${PATH_TMP}/boot-configtxt-$(basename ${ENTER_board_name})"
    if [ -d $path_tmp_package_configtxt ]; then
        rm -r $path_tmp_package_configtxt
    fi
    create_dir $path_tmp_package_configtxt
    local path_board_tmp_boot="/tmp-boot/boot-configtxt"
    local path_tmp_boot=${path_tmp_package_configtxt}${path_board_tmp_boot}
    create_dir  $path_tmp_boot
    cp ${ENTER_board_name}/config.txt $path_tmp_boot
    _gen_postinst_cp_file $path_tmp_package_configtxt $path_board_tmp_boot /boot/
    
    
    postinst_file=$path_tmp_package_configtxt/DEBIAN/postinst
    if [ ! -d $path_tmp_package_configtxt/DEBIAN ];then
        mkdir $path_tmp_package_configtxt/DEBIAN
    fi
   cat << EOF > $postinst_file
#!/bin/sh
case "\$1" in
    configure)
        old_version="\$2"
        new_version="\$3"
        echo "Updating from version $old_version to version $new_version"

        cp -r $path_board_tmp_boot/* /boot/
        set-device

        BLOCK_DEVICE=\$(findmnt "/" -o SOURCE -n)
        ROOTFS_PARTUUID=\$(blkid -s PARTUUID -o value \$BLOCK_DEVICE)
        if [ -z "\$ROOTFS_PARTUUID" ]; then
            echo "无法解析出uuid"
            exit
        fi
        echo "rootdev=PARTUUID=\${ROOTFS_PARTUUID}" | sudo tee -a /boot/config.txt

        ;;
    abort-upgrade|abort-remove|abort-deconfigure)
        # 回滚操作
        ;;

esac
exit 0
EOF
    
    
    _pack_as_boot_deb $path_tmp_package_configtxt "configtxt" "config.txt for boot"
}

pack_boot_bin() {
    local path_tmp_package_configtxt="${PATH_TMP}/boot-bin-$(basename ${ENTER_board_name})"
    if [ -d $path_tmp_package_configtxt ]; then
        rm -r $path_tmp_package_configtxt
    fi
    create_dir $path_tmp_package_configtxt
    local path_board_tmp_boot="/tmp-boot/boot"
    local path_tmp_boot=${path_tmp_package_configtxt}${path_board_tmp_boot}
    create_dir  $path_tmp_boot
    
    
    cp_file_if_exsit ${ENTER_board_name}/boot.cmd $path_tmp_boot
    cp_file_if_exsit ${ENTER_board_name}/boot.scr $path_tmp_boot
    cp_file_if_exsit ${OUTFILE_boot_bin} $path_tmp_boot
    # 装入本项目保存的bin文件
    if [ -d $PATH_save_boot_files ]; then
        cp -r $PATH_save_boot_files/* $path_tmp_boot
    fi
    
    postinst_file=$path_tmp_package_configtxt/DEBIAN/postinst
    mkdir $path_tmp_package_configtxt/DEBIAN
cat << EOF > $postinst_file
#!/bin/sh
case "\$1" in
    configure)
        old_version="\$2"
        new_version="\$3"
        echo "Updating from version $old_version to version $new_version"
        cp -r $path_board_tmp_boot/* /boot/

        BLOCK_DEVICE=\$(findmnt "/boot" -o SOURCE -n)
        echo "BLOCK_DEVICE=\$BLOCK_DEVICE"
        BASE_DEVICE=\$(echo "\$BLOCK_DEVICE" | sed -E 's/p[0-9]+\$//')
        if [ -z "\$BASE_DEVICE" ]; then
            echo "无法解析出块设备路径"
            exit
        fi
        dd_command="dd if=/boot/boot.bin of=\$BASE_DEVICE bs=1K seek=8 conv=notrunc"
        echo "\$dd_command"
        eval \$dd_command
    ;;
    abort-upgrade|abort-remove|abort-deconfigure)
        # 回滚操作
        ;;
    *)
        exit 1
        ;;
esac

exit 0
EOF
    chmod 755 $postinst_file
    
    _pack_as_boot_deb $path_tmp_package_configtxt "bootbin" "the boot bin"
}

build_bootloader()
{
    if [ -d $OUTDIR_boot_package ]; then
        rm -r $OUTDIR_boot_package
    fi
    create_dir $OUTDIR_boot_package
    if [ -n "$UBOOT_CONFIG" ];then
        compile_uboot
    fi
    if [ -n "$SYTERKIT_BOARD_FILE" ];then
        compile_syterkit
    fi
    pack_config_txt
    pack_boot_bin
}
