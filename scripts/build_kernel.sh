#!/bin/bash

PACKAGE_IMAGE_NAME=linux-image-${BOARD_MODEL}-${LINUX_BRANCH}
DEB_IMAGE_NAME=${PACKAGE_IMAGE_NAME}_1.0.0_all.deb
reload_env

if [ -d $PATH_OUTPUT_KERNEL_PACKAGE ]; then
    rm -r $PATH_OUTPUT_KERNEL_PACKAGE
fi
create_dir $PATH_OUTPUT_KERNEL_PACKAGE

# 获取linux版本号，如5.15.147 6.1.9
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
    echo "$version.$patchlevel.$sublevel$extraversion"
}



is_enabled() {
    grep -q "^$1=y" include/config/auto.conf
}




compile_kernel() {
    
    cd $PATH_KERNEL
    if [ ! -f .scmversion ]; then
        run_as_user touch .scmversion
    fi
    
    
    thread_count=$(grep -c ^processor /proc/cpuinfo)
    run_as_user make $LINUX_CONFIG CROSS_COMPILE=$USE_CROSS_COMPILE ARCH=${CHIP_ARCH}
    run_as_user make -j$thread_count CROSS_COMPILE=$USE_CROSS_COMPILE ARCH=${CHIP_ARCH}
    
    exit_if_last_error
    
    echo "kernel compile success"
}


# 生成deb包需要的postinst文件，功能是在安装时复制指定的文件到指定路径
_gen_postinst_cp_file(){
    local path_package=$1
    local source_path=$2
    local target_path=$3
    postinst_file=$path_package/DEBIAN/postinst
    if [ ! -d $path_package/DEBIAN ];then
        mkdir $path_package/DEBIAN
    fi
   cat << EOF > $postinst_file
#!/bin/sh
set -e
case "\$1" in
    configure)
        old_version="\$2"
        new_version="\$3"
        echo "Updating from version $old_version to version $new_version"

        cp -r $source_path/* $target_path

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
}

_gen_tmp_package_dir(){
    local name=$1
    local TMP_KERNEL_DEB="${PATH_TMP}/${name}-${LINUX_CONFIG}_${LINUX_BRANCH}"
    if [[ -d $TMP_KERNEL_DEB ]]; then
        rm -r $TMP_KERNEL_DEB
    fi
    echo $TMP_KERNEL_DEB
}

# 填写control文件,生成deb包到输出路径
_pack_as_deb(){
    local path_package=$1
    local part_name=$2
    local package_desc=$3
    
    local package_name="$part_name-${BOARD_NAME}-${LINUX_BRANCH}"
    control_file=$path_package/DEBIAN/control
    
    if [ ! -d $path_package/DEBIAN ];then
        mkdir -p $path_package/DEBIAN
    fi
    
    # 从本build项目第一次提交时间起，linux项目共发生了几次提交，将提交数作为deb包的版本号
    cd $PATH_PWD
    git config --global --add safe.directory $PATH_PWD
    build_commit_time=$(git log --reverse --pretty=format:"%ad" --date=format:'%Y-%m-%d' | head -n 1)
    cd $PATH_KERNEL
    git_log=$(git log --since="$build_commit_time"  --oneline)
    commit_count=$(echo "$git_log" | wc -l)
    deb_version="1.$commit_count.0"
    
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
    DEB_IMAGE_NAME="${package_name}_${deb_version}_${CHIP_ARCH}.deb"
    run_status "创建deb包 ${DEB_IMAGE_NAME} " dpkg -b "$path_package" "${PATH_OUTPUT_KERNEL_PACKAGE}/${DEB_IMAGE_NAME}"
    
}

pack_kernel_Image() {
    part_name="kernel-image"
    local TMP_KERNEL_DEB=$(_gen_tmp_package_dir $part_name)
    
    local path_board_tmp_boot="/tmp-boot/Image"
    local path_tmp_boot=${TMP_KERNEL_DEB}${path_board_tmp_boot}
    create_dir  $path_tmp_boot
    
    cp ${PATH_KERNEL}/.config $path_tmp_boot/config-$(get_linux_version ./)
    cd $PATH_KERNEL
    run_status "export Image" cp ${PATH_KERNEL}/arch/${CHIP_ARCH}/boot/Image $path_tmp_boot
    
    _gen_postinst_cp_file $TMP_KERNEL_DEB $path_board_tmp_boot /boot/
    _pack_as_deb $TMP_KERNEL_DEB $part_name "linux kernel image file"
    
}
pack_kernel_dtb() {
    part_name="kernel-dtb"
    local TMP_KERNEL_DEB=$(_gen_tmp_package_dir $part_name)
    
    local path_board_tmp_boot="/tmp-boot/dtb"
    local path_tmp_boot=${TMP_KERNEL_DEB}${path_board_tmp_boot}
    create_dir  $path_tmp_boot
    
    cd $PATH_KERNEL
    run_status "export device-tree" make dtbs_install INSTALL_DTBS_PATH="$path_tmp_boot" ARCH=${CHIP_ARCH}
    
    # 设备树导出后，会产生一个类似allwinner/.dtb的路径，把里面的dtb提取到外面
    folder_name=$(ls -d $path_tmp_boot/*/ | head -n 1)
    cp -r $folder_name* $path_tmp_boot
    rm -r $folder_name
    
    _gen_postinst_cp_file $TMP_KERNEL_DEB $path_board_tmp_boot /boot/
    _pack_as_deb $TMP_KERNEL_DEB $part_name "linux kernel dtb files"
}


pack_kernel_modules() {
    part_name="kernel-modules"
    local TMP_KERNEL_DEB=$(_gen_tmp_package_dir $part_name)
    
    cd $PATH_KERNEL
    run_status "export modules" make  modules_install INSTALL_MOD_PATH="$TMP_KERNEL_DEB" ARCH=${CHIP_ARCH}
    
    for dir in $TMP_KERNEL_DEB/lib/modules/*/
    do
        # 这个build文件夹指向源码绝对位置，要删掉
        if [ -d "${dir}build" ]; then
            rm -rf "${dir}build"
        fi
        # 这个source文件夹指向源码绝对位置，要删掉
        if [ -d "${dir}source" ]; then
            rm -rf "${dir}source"
        fi
    done
    
    _pack_as_deb $TMP_KERNEL_DEB $part_name "linux kernel modules"
    
}

# 进入linux项目源码路径下调用
# 调用前运行先clean
# 将linux-headers相关文件生成到参数1指定路径
generate_kernel_headers() {
    local tmpdir=$1
    local arch=$2
    local version=$(get_linux_version ./)
    
    local destdir=$tmpdir/usr/src/linux-headers-$version
    create_dir $destdir
    if [ -d debian ];then
        rm -rf debian
    fi
    create_dir debian
    
    configobj=CONFIG_OBJTOOL
    
    # Collect source files
    (
        find . -name Makefile\* -o -name Kconfig\* -o -name \*.pl -o -name \*.mk
        find arch/*/include include scripts -type f -o -type l
        find security/*/include -type f
        find arch/$arch -name module.lds -o -name Kbuild.platforms -o -name Platform
        find $(find arch/$arch -name include -o -name scripts -o -name tools -type d) -type f
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
    
    
    # 检测以scrpt开头的文件，删除那些被写进.gitignore的
    process_file() {
        local input_file="$1"
        local temp_file=$(mktemp)
        
        while IFS= read -r line; do
            if [[ $line == scripts* ]]; then
                if ! git check-ignore -q "$line"; then
                    echo "$line" >> "$temp_file"
                fi
            else
                echo "$line" >> "$temp_file"
            fi
        done < "$input_file"
        
        cat "$temp_file" > "$input_file"
    }
    
    process_file debian/hdrsrcfiles
    process_file debian/hdrobjfiles
    echo "scripts/module.lds" >> debian/hdrsrcfiles
    
    tar -c -f - -C ./ -T debian/hdrsrcfiles | tar -xf - -C $destdir
    tar -c -f - -T debian/hdrobjfiles | tar -xf - -C $destdir
    
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
replace_or_append "toolchain" "toolchain=$TOOLCHAIN_FILE_NAME$TOOLCHAIN_NAME_IN_APT"

# update-initramfs -uv -k $version

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
pack_kernel_headers() {
    part_name="kernel-headers"
    
    local TMP_KERNEL_DEB=$(_gen_tmp_package_dir $part_name)
    
    PATH_KERNEL_CLEAN="${PATH_KERNEL}-clean"
    if [ -d $PATH_KERNEL_CLEAN ]; then
        rm -r $PATH_KERNEL_CLEAN
    fi
    run_status "copy kernel" run_as_user cp -r $PATH_KERNEL $PATH_KERNEL_CLEAN
    
    cd $PATH_KERNEL_CLEAN
    run_status "make the kernel clean" run_as_user make clean CROSS_COMPILE=$USE_CROSS_COMPILE ARCH=${CHIP_ARCH}
    
    cd $PATH_KERNEL_CLEAN
    local version=$(get_linux_version ./)
    local destdir=$TMP_KERNEL_DEB/usr/src/linux-headers-$version
    create_dir $destdir
    create_dir debian
    
    cd $PATH_KERNEL_CLEAN
    make clean CROSS_COMPILE=$USE_CROSS_COMPILE ARCH=${CHIP_ARCH}
    generate_kernel_headers $TMP_KERNEL_DEB $CHIP_ARCH
    
    _pack_as_deb $TMP_KERNEL_DEB $part_name "linux kernel header files"
    
}

build_kernel() {
    cd $PATH_SOURCE
    clone_branch $LINUX_GIT $LINUX_BRANCH $PATH_KERNEL
    git config --global --add safe.directory $PATH_KERNEL
    
    compile_kernel
    pack_kernel_Image
    pack_kernel_dtb
    pack_kernel_modules
    pack_kernel_headers

}