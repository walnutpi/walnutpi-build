#!/bin/bash

PACKAGE_IMAGE_NAME=linux-image-${BOARD_NAME_SMALL}-${LINUX_BRANCH}
DEB_IMAGE_NAME=${PACKAGE_IMAGE_NAME}_1.0.0_all.deb


PATH_KERNEL_PACKAGE=${PATH_OUTPUT}/kernel-${BOARD_NAME}
create_dir $PATH_KERNEL_PACKAGE



COMPILE_ATF() {
    cd $PATH_SOURCE
    echo $ATF_GIT
    clone_url $ATF_GIT
    dirname="${PATH_SOURCE}/$(basename "$ATF_GIT" .git)"
    cd $dirname
    run_as_user make PLAT=$ATF_PLAT  DEBUG=1 bl31 CROSS_COMPILE=$FILE_CROSS_COMPILE
    exit_if_last_error
}

compile_uboot() {
    if [ -n "$ATF_GIT" ]; then
        COMPILE_ATF
    fi
    cd $PATH_SOURCE
    
    dirname="${PATH_SOURCE}/$(basename "$UBOOT_GIT" .git)-$UBOOT_BRANCH"
    
    clone_branch $UBOOT_GIT $UBOOT_BRANCH $dirname
    cd $dirname
    
    run_as_user make $UBOOT_CONFIG
    run_as_user make BL31=../arm-trusted-firmware/build/$ATF_PLAT/debug/bl31.bin \
    CROSS_COMPILE=$FILE_CROSS_COMPILE
    exit_if_last_error
    cp $UBOOT_BIN_NAME $PATH_OUTPUT
    
}

get_linux_version() {
    # $1 是传入的 Linux 源码项目的位置
    local src_dir=$1
    
    if [[ ! -d "$src_dir" ]]; then
        echo "目录不存在: $src_dir"
        return 1
    fi
    
    local makefile="$src_dir/Makefile"
    if [[ ! -f "$makefile" ]]; then
        echo "在目录中找不到 Makefile: $src_dir"
        return 1
    fi
    
    local version=$(grep -E '^VERSION = ' $makefile | cut -d ' ' -f 3)
    local patchlevel=$(grep -E '^PATCHLEVEL = ' $makefile | cut -d ' ' -f 3)
    local sublevel=$(grep -E '^SUBLEVEL = ' $makefile | cut -d ' ' -f 3)
    local extraversion=$(grep -E '^EXTRAVERSION = ' $makefile | cut -d ' ' -f 3)
    # local status=$(cd $src_dir && git status --porcelain)
    
    
    # if [[ -n "$status" ]]; then
    #     extraversion="$extraversion+"
    # fi
    
    # 输出版本信息
    echo "$version.$patchlevel.$sublevel$extraversion"
}



is_enabled() {
    grep -q "^$1=y" include/config/auto.conf
}


# 进入linux项目源码路径下调用
# 调用前运行先clean
# 将linux-headers相关文件生成到参数1指定路径
generate_kernel_headers() {
    tmpdir=$1
    arch=$2
    version=$(get_linux_version ./)
    
    destdir=$tmpdir/usr/src/linux-headers-$version
    create_dir $destdir
    create_dir debian
    
    
    configobj=CONFIG_OBJTOOL
    (
        find . -name Makefile\* -o -name Kconfig\* -o -name \*.pl
        find arch/*/include include scripts -type f -o -type l
        find security/*/include -type f
        find arch/$arch -name module.lds -o -name Kbuild.platforms -o -name Platform
        find $(find arch/$arch -name include -o -name scripts -type d) -type f
    ) > debian/hdrsrcfiles
    
    {
        # This affects arch/x86
        if is_enabled $configobj; then
            #	echo tools/objtool/objtool
            find tools/objtool -type f -executable
        fi
        
        find arch/$arch/include Module.symvers include scripts -type f
        
        if is_enabled CONFIG_GCC_PLUGINS; then
            find scripts/gcc-plugins -name \*.so -o -name gcc-common.h
        fi
        find tools/ -name "*e_byteshift.h"
    } > debian/hdrobjfiles
    
    
    tar -c -f - -C ./ -T debian/hdrsrcfiles | tar -xf - -C $destdir
    tar -c -f - -T debian/hdrobjfiles | tar -xf - -C $destdir
    rm -f debian/hdrsrcfiles debian/hdrobjfiles
    
    # copy .config manually to be where it's expected to be
    create_dir $tmpdir/DEBIAN
    [[ ! -f $tmpdir/DEBIAN/postinst ]] && touch $tmpdir/DEBIAN/postinst
    relseas_file="/etc/WalnutPi-release"
    
    cat << EOF > $tmpdir/DEBIAN/postinst
#!/bin/bash
cd /usr/src/linux-headers-$version

echo "Compiling headers - please wait ..."
yes "" | make ARCH=$arch clean
NCPU=\$(grep -c 'processor' /proc/cpuinfo)
find -type f -exec touch {} +
yes "" | make ARCH=$arch oldconfig
make -j\$NCPU ARCH=$arch -s scripts
make -j\$NCPU ARCH=$arch -s M=scripts/mod/
echo "Compiling end"

function replace_or_append() {
    local file_path="$relseas_file"
    local search_string="\$1"
    local replace_string="\$2"

    if grep -q "^\$search_string" "\$file_path"; then
        sed -i "/^\$search_string/c\\\\\$replace_string" "\$file_path"
    else
        echo "\$replace_string" >> "\$file_path"
    fi
}
replace_or_append "kernel_git" "kernel_git=$LINUX_GIT"
replace_or_append "kernel_branch" "kernel_branch=$LINUX_BRANCH"
replace_or_append "kernel_config" "kernel_config=$LINUX_CONFIG"
replace_or_append "toolchain" "toolchain=$TOOLCHAIN_FILE_NAME"

update-initramfs -uv -k $version

EOF
    chmod +x $tmpdir/DEBIAN/postinst
    
    cat << EOF > $tmpdir/DEBIAN/postrm
#!/bin/bash
if [ "$1" = "remove" ]  ; then
    if [ -d /usr/src/linux-headers-$version ]; then
        rm -r /usr/src/linux-headers-$version
    fi
fi
EOF
    chmod +x $tmpdir/DEBIAN/postrm
    
    #     cat << EOF > $tmpdir/DEBIAN/preinst
    # #!/bin/bash
    # if [ -d /usr/src/linux-headers-$version ]; then
    #     echo "remove old linux-headers"
    #     rm -r /usr/src/linux-headers-$version
    # fi
    # exit 0
    # EOF
    #     chmod +x $tmpdir/DEBIAN/preinst
    
    cp .config  $destdir/.config
    create_dir $tmpdir/lib/modules/$version
    ln -s /usr/src/linux-headers-$version $tmpdir/lib/modules/$version/build
    
    
}

compile_kernel() {
    cd $PATH_SOURCE
    
    PATH_KERNEL="${PATH_SOURCE}/$(basename "$LINUX_GIT" .git)-$LINUX_BRANCH"
    clone_branch $LINUX_GIT $LINUX_BRANCH $PATH_KERNEL
    
    cd $PATH_KERNEL
    if [ ! -f .scmversion ]; then
        run_as_user touch .scmversion
    fi
    
    
    thread_count=$(grep -c ^processor /proc/cpuinfo)
    run_as_user make $LINUX_CONFIG CROSS_COMPILE=$FILE_CROSS_COMPILE ARCH=${CHIP_ARCH}
    run_as_user make -j$thread_count CROSS_COMPILE=$FILE_CROSS_COMPILE ARCH=${CHIP_ARCH}
    
    exit_if_last_error
    
    echo "kernel compile success"
    
    TMP_KERNEL_DEB=${PATH_TMP}/kernel_${LINUX_CONFIG}_${LINUX_BRANCH}
    if [[ -d $TMP_KERNEL_DEB ]]; then
        rm -r $TMP_KERNEL_DEB
    fi
    create_dir  $TMP_KERNEL_DEB/boot
    
    cp ${PATH_KERNEL}/.config $TMP_KERNEL_DEB/boot/config-$(get_linux_version ./)
    run_status "export Image" cp ${PATH_KERNEL}/arch/${CHIP_ARCH}/boot/Image $TMP_KERNEL_DEB/boot/
    run_status "export modules" make  modules_install INSTALL_MOD_PATH="$TMP_KERNEL_DEB" ARCH=${CHIP_ARCH}
    run_status "export device-tree" make dtbs_install INSTALL_DTBS_PATH="$TMP_KERNEL_DEB/boot/" ARCH=${CHIP_ARCH}
    
    # 设备树导出后，会产生一个allwinner/.dtb的路径，把里面的dtb提取到外面
    folder_name=$(ls -d $TMP_KERNEL_DEB/boot/*/ | head -n 1)
    cp -r $folder_name* $TMP_KERNEL_DEB/boot/
    rm -r $folder_name
    if [[ -d $TMP_KERNEL_DEB/boot/overlay  ]]; then
        mv $TMP_KERNEL_DEB/boot/overlay $TMP_KERNEL_DEB/boot/overlays
    fi
    
    # 这个build文件夹指向源码绝对位置，要删掉
    for dir in $TMP_KERNEL_DEB/lib/modules/*/
    do
        if [ -d "${dir}build" ]; then
            rm -rf "${dir}build"
        fi
    done
    
    run_status "boot.scr" mkimage -C none -A arm -T script -d ${DIR_BOARD}/boot.cmd ${DIR_BOARD}/boot.scr
    cp ${DIR_BOARD}/boot.cmd $TMP_KERNEL_DEB/boot/
    cp ${DIR_BOARD}/boot.scr $TMP_KERNEL_DEB/boot/
    cp ${DIR_BOARD}/config.txt $TMP_KERNEL_DEB/boot/
    
    create_dir $TMP_KERNEL_DEB/DEBIAN
    
    PATH_KERNEL_CLEAN="${PATH_KERNEL}-clean"
    if [ ! -d $PATH_KERNEL_CLEAN ]; then
        run_as_user cp -r $PATH_KERNEL $PATH_KERNEL_CLEAN
    fi
    
    # 导出linux-headers文件
    cd $PATH_KERNEL_CLEAN
    run_as_user make clean CROSS_COMPILE=$FILE_CROSS_COMPILE ARCH=${CHIP_ARCH}
    generate_kernel_headers $TMP_KERNEL_DEB $CHIP_ARCH
    
    # 如果用apt更新，会在为vfat分区内的文件创建备份时报错，所以本包的文件都不存在/boot路径下
    mv $TMP_KERNEL_DEB/boot/ $TMP_KERNEL_DEB/tmp-boot/
    if [[ ! -f $TMP_KERNEL_DEB/DEBIAN/postinst ]]; then
        echo "创建$TMP_KERNEL_DEB/DEBIAN/postinst"
        touch $TMP_KERNEL_DEB/DEBIAN/postinst
    fi
    cat << EOF >> $TMP_KERNEL_DEB/DEBIAN/postinst
cp -r /tmp-boot/* /boot/
EOF
    chmod +x $TMP_KERNEL_DEB/DEBIAN/postinst
    
    
    [[ -d ${PATH_KERNEL_PACKAGE}/  ]] && rm -r ${PATH_KERNEL_PACKAGE}/
    create_dir ${PATH_KERNEL_PACKAGE}
    
    # 计算准备写进deb包的控制信息
    
    # 计算本build项目第一次提交的时间
    cd $PATH_PWD
    build_commit_time=$(git log --reverse --pretty=format:"%ad" --date=format:'%Y-%m-%d' | head -n 1)
    # echo $build_commit_time
    
    # 从本build项目第一次提交时间起，linux项目共发生了几次提交，将提交数作为deb包的版本号
    cd $PATH_KERNEL
    git_log=$(git log --since="$build_commit_time"  --oneline)
    commit_count=$(echo "$git_log" | wc -l)
    deb_version="1.$commit_count.0"
    DEB_IMAGE_NAME=${PACKAGE_IMAGE_NAME}_${deb_version}_${CHIP_ARCH}.deb
    
    
    cd $TMP_KERNEL_DEB
    size=$(du -sk --exclude=DEBIAN . | cut -f1)
    echo "size=$size"
    git_email=$(git config --global user.email)
    
    [[ ! -d $TMP_KERNEL_DEB/DEBIAN ]] && mkdir -p $TMP_KERNEL_DEB/DEBIAN
    cat << EOF > $TMP_KERNEL_DEB/DEBIAN/control
Package: ${PACKAGE_IMAGE_NAME}
Description: linux kernel file
Maintainer: ${git_email}
Version: ${deb_version}
Section: free
Priority: optional
Installed-Size: ${size}
Architecture: ${CHIP_ARCH}
EOF
    
    run_status "创建deb包 ${DEB_IMAGE_NAME} " dpkg -b "$TMP_KERNEL_DEB" "${PATH_KERNEL_PACKAGE}/${DEB_IMAGE_NAME}"
    
}

