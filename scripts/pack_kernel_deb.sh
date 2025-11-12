#!/bin/bash

# 生成临时包目录
# 参数说明:
# $1 - name: 包名称
# $2 - PATH_TMP: 临时路径
# $3 - LINUX_CONFIG: 内核配置
# $4 - LINUX_BRANCH: 内核分支
_gen_tmp_package_dir() {
    local name=$1
    local PATH_TMP=$2
    local LINUX_CONFIG=$3
    local LINUX_BRANCH=$4

    local TMP_KERNEL_DEB="${PATH_TMP}/${name}-${LINUX_CONFIG}_${LINUX_BRANCH}"
    if [[ -d $TMP_KERNEL_DEB ]]; then
        rm -r "$TMP_KERNEL_DEB"
    fi
    echo "$TMP_KERNEL_DEB"
}

# 填写control文件,生成deb包到输出路径
# 参数说明:
# $1 - path_package: 包路径
# $2 - part_name: 部件名称
# $3 - package_desc: 包描述
# $4 - BOARD_MODEL: 板级模型
# $5 - LINUX_BRANCH: 内核分支
# $6 - CHIP_ARCH: 芯片架构
# $7 - PATH_PROJECT_DIR: 项目路径
# $8 - SOURCE_kernel: 内核源码路径
# $9 - OUTDIR_kernel_package: 内核包输出目录
_pack_as_kernel_deb() {
    local path_package=$1
    local part_name=$2
    local package_desc=$3
    local BOARD_MODEL=$4
    local LINUX_BRANCH=$5
    local CHIP_ARCH=$6
    local PATH_PROJECT_DIR=$7
    local SOURCE_kernel=$8
    local OUTDIR_kernel_package=$9
    echo "path_package: $path_package"
    echo "part_name: $part_name"
    echo "package_desc: $package_desc"
    echo "BOARD_MODEL: $BOARD_MODEL"
    echo "LINUX_BRANCH: $LINUX_BRANCH"
    echo "CHIP_ARCH: $CHIP_ARCH"
    echo "PATH_PROJECT_DIR: $PATH_PROJECT_DIR"
    echo "SOURCE_kernel: $SOURCE_kernel"
    echo "OUTDIR_kernel_package: $OUTDIR_kernel_package"

    local PACKAGE_IMAGE_NAME="linux-image-${BOARD_MODEL}-${LINUX_BRANCH}"
    local DEB_IMAGE_NAME="${PACKAGE_IMAGE_NAME}_1.0.0_all.deb"

    local package_name="$part_name-${BOARD_MODEL}-${LINUX_BRANCH}"
    local control_file="$path_package/DEBIAN/control"

    if [ ! -d "$path_package/DEBIAN" ]; then
        mkdir -p "$path_package/DEBIAN"
    fi

    # 从本build项目第一次提交时间起，linux项目共发生了几次提交，将提交数作为deb包的版本号
    cd "$PATH_PROJECT_DIR"
    git config --global --add safe.directory "$PATH_PROJECT_DIR"
    local build_commit_time=$(git log --reverse --pretty=format:"%ad" --date=format:'%Y-%m-%d' | head -n 1)
    cd "$SOURCE_kernel"
    git config --global --add safe.directory "$SOURCE_kernel"
    local git_log=$(git log --since="$build_commit_time" --oneline)
    local commit_count=$(echo "$git_log" | wc -l)
    local deb_version="1.$commit_count.0"
    echo "deb_version: $deb_version"
    cd "$path_package"
    local size=$(du -sk --exclude=DEBIAN . | cut -f1)

    cat <<EOF >"$control_file"
Package: ${package_name}
Description: ${package_desc}
Maintainer: walnutpi-build
Version: ${deb_version}
Section: free
Priority: optional
Installed-Size: ${size}
Architecture: ${CHIP_ARCH}
EOF
    local DEB_IMAGE_NAME="${package_name}_${deb_version}_${CHIP_ARCH}.deb"
    # 假设 run_status 是一个全局函数，这里保留它
    run_status "创建deb包 ${DEB_IMAGE_NAME}" dpkg -b "$path_package" "${OUTDIR_kernel_package}/${DEB_IMAGE_NAME}"
}

# 打包内核镜像
# 参数说明:
# $1 - PATH_PROJECT_DIR: 项目所在绝对路径
# $2 - SOURCE_kernel: 内核源码路径
# $3 - CHIP_ARCH: 芯片架构
# $4 - PATH_TMP: 临时路径
# $5 - LINUX_CONFIG: 内核配置
# $6 - LINUX_BRANCH: 内核分支
# $7 - BOARD_NAME: 板子名称
# $8 - OUTDIR_kernel_package: 内核包输出目录
pack_kernel_Image() {
    local PATH_PROJECT_DIR=$1
    local SOURCE_kernel=$2
    local CHIP_ARCH=$3
    local PATH_TMP=$4
    local LINUX_CONFIG=$5
    local LINUX_BRANCH=$6
    local BOARD_NAME=$7
    local OUTDIR_kernel_package=$8

    echo "SOURCE_kernel: $SOURCE_kernel"
    echo "CHIP_ARCH: $CHIP_ARCH"
    echo "PATH_TMP: $PATH_TMP"
    echo "LINUX_CONFIG: $LINUX_CONFIG"
    echo "LINUX_BRANCH: $LINUX_BRANCH"
    echo "BOARD_NAME: $BOARD_NAME"
    echo "OUTDIR_kernel_package: $OUTDIR_kernel_package"

    local part_name="kernel-image"
    local TMP_KERNEL_DEB=$(_gen_tmp_package_dir "$part_name" "$PATH_TMP" "$LINUX_CONFIG" "$LINUX_BRANCH")

    local path_board_tmp_boot="/tmp-boot/Image"
    local path_tmp_boot="${TMP_KERNEL_DEB}${path_board_tmp_boot}"
    mkdir -p "$path_tmp_boot"

    cp "${SOURCE_kernel}/.config" "$path_tmp_boot/config-$(get_linux_version "$SOURCE_kernel")"
    cd "$SOURCE_kernel"
    run_status "export Image" cp "${SOURCE_kernel}/arch/${CHIP_ARCH}/boot/Image" "$path_tmp_boot"

    _gen_postinst_cp_file "$TMP_KERNEL_DEB" "$path_board_tmp_boot" /boot/
    _pack_as_kernel_deb "$TMP_KERNEL_DEB" "$part_name" "linux kernel image file" \
        "$BOARD_NAME" "$LINUX_BRANCH" "$CHIP_ARCH" "$PATH_PROJECT_DIR" "$SOURCE_kernel" "$OUTDIR_kernel_package"
}

# 打包设备树
# 参数说明:
# $1 - PATH_PROJECT_DIR: 项目所在绝对路径
# $2 - SOURCE_kernel: 内核源码路径
# $3 - CHIP_ARCH: 芯片架构
# $4 - PATH_TMP: 临时路径
# $5 - LINUX_CONFIG: 内核配置
# $6 - LINUX_BRANCH: 内核分支
# $7 - BOARD_NAME: 板子名称
# $8 - OUTDIR_kernel_package: 内核包输出目录
pack_kernel_dtb() {
    local PATH_PROJECT_DIR=$1
    local SOURCE_kernel=$2
    local CHIP_ARCH=$3
    local PATH_TMP=$4
    local LINUX_CONFIG=$5
    local LINUX_BRANCH=$6
    local BOARD_NAME=$7
    local OUTDIR_kernel_package=$8

    # 输出所有传入的参数
    echo "PATH_PROJECT_DIR: $PATH_PROJECT_DIR"
    echo "SOURCE_kernel: $SOURCE_kernel"
    echo "CHIP_ARCH: $CHIP_ARCH"
    echo "PATH_TMP: $PATH_TMP"
    echo "LINUX_CONFIG: $LINUX_CONFIG"
    echo "LINUX_BRANCH: $LINUX_BRANCH"
    echo "BOARD_NAME: $BOARD_NAME"
    echo "OUTDIR_kernel_package: $OUTDIR_kernel_package"

    local part_name="kernel-dtb"
    local TMP_KERNEL_DEB=$(_gen_tmp_package_dir "$part_name" "$PATH_TMP" "$LINUX_CONFIG" "$LINUX_BRANCH")

    local path_board_tmp_boot="/tmp-boot/dtb"
    local path_tmp_boot="${TMP_KERNEL_DEB}${path_board_tmp_boot}"
    mkdir -p "$path_tmp_boot"

    cd "$SOURCE_kernel"
    run_status "export device-tree" make dtbs_install INSTALL_DTBS_PATH="$path_tmp_boot" ARCH="$CHIP_ARCH"

    # 设备树导出后，会产生一个类似allwinner/.dtb的路径，把里面的dtb提取到外面
    local folder_name=$(ls -d "$path_tmp_boot"/*/ | head -n 1)
    cp -r "${folder_name}"* "$path_tmp_boot"
    rm -r "$folder_name"

    _gen_postinst_cp_file "$TMP_KERNEL_DEB" "$path_board_tmp_boot" /boot/
    echo "set-device" >>"$TMP_KERNEL_DEB/DEBIAN/postinst"
    echo "echo \"ok\"" >>"$TMP_KERNEL_DEB/DEBIAN/postinst"
    _pack_as_kernel_deb "$TMP_KERNEL_DEB" "$part_name" "linux kernel dtb files" \
        "$BOARD_NAME" "$LINUX_BRANCH" "$CHIP_ARCH" "$PATH_PROJECT_DIR" "$SOURCE_kernel" "$OUTDIR_kernel_package"
}

# 打包内核模块
# 参数说明:
# $1 - PATH_PROJECT_DIR: 项目所在绝对路径
# $2 - SOURCE_kernel: 内核源码路径
# $3 - CHIP_ARCH: 芯片架构
# $4 - PATH_TMP: 临时路径
# $5 - LINUX_CONFIG: 内核配置
# $6 - LINUX_BRANCH: 内核分支
# $7 - BOARD_NAME: 板子名称
# $8 - OUTDIR_kernel_package: 内核包输出目录
# $9 - create_dir: 创建目录的函数
pack_kernel_modules() {
    local PATH_PROJECT_DIR=$1
    local SOURCE_kernel=$2
    local CHIP_ARCH=$3
    local PATH_TMP=$4
    local LINUX_CONFIG=$5
    local LINUX_BRANCH=$6
    local BOARD_NAME=$7
    local OUTDIR_kernel_package=$8
    local create_dir=$9

    local part_name="kernel-modules"
    local TMP_KERNEL_DEB=$(_gen_tmp_package_dir "$part_name" "$PATH_TMP" "$LINUX_CONFIG" "$LINUX_BRANCH")

    cd "$SOURCE_kernel"
    run_status "export modules" make modules_install INSTALL_MOD_PATH="$TMP_KERNEL_DEB" ARCH="$CHIP_ARCH"

    for dir in "$TMP_KERNEL_DEB"/lib/modules/*/; do
        # 这个build文件夹指向源码绝对位置，要删掉
        if [ -d "${dir}build" ]; then
            rm -rf "${dir}build"
        fi
        # 这个source文件夹指向源码绝对位置，要删掉
        if [ -d "${dir}source" ]; then
            rm -rf "${dir}source"
        fi
    done
    local postinst_file="$TMP_KERNEL_DEB/DEBIAN/postinst"
    if [ ! -d "$TMP_KERNEL_DEB/DEBIAN" ]; then
        mkdir -p "$TMP_KERNEL_DEB/DEBIAN"
    fi
    cat <<EOF >"$postinst_file"
#!/bin/sh
case "\$1" in
    configure)
        echo "update modules"
        depmod
        ;;
    abort-upgrade|abort-remove|abort-deconfigure)
        # 回滚操作
        ;;

esac
exit 0
EOF
    chmod 755 "$postinst_file"

    _pack_as_kernel_deb "$TMP_KERNEL_DEB" "$part_name" "linux kernel modules" \
        "$BOARD_NAME" "$LINUX_BRANCH" "$CHIP_ARCH" "$PATH_PROJECT_DIR" "$SOURCE_kernel" "$OUTDIR_kernel_package"
}

# 生成内核头文件
# 参数说明:
# $1 - tmpdir: 临时目录
# $2 - arch: 架构
# $3 - LINUX_GIT: 内核Git地址
# $4 - LINUX_BRANCH: 内核分支
# $5 - LINUX_CONFIG: 内核配置
# $6 - TOOLCHAIN_FILE_NAME: 工具链文件名
# $7 - TOOLCHAIN_NAME_IN_APT: APT中的工具链名称
generate_kernel_headers() {
    local tmpdir=$1
    local arch=$2
    local LINUX_GIT=$3
    local LINUX_BRANCH=$4
    local LINUX_CONFIG=$5
    local TOOLCHAIN_FILE_NAME=$6
    local TOOLCHAIN_NAME_IN_APT=$7

    local version=$(get_linux_version .)

    local destdir="$tmpdir/usr/src/linux-headers-$version"
    create_dir "$destdir"
    if [ -d debian ]; then
        rm -rf debian
    fi
    create_dir debian

    local configobj=CONFIG_OBJTOOL
    is_enabled() {
        grep -q "^$1=y" include/config/auto.conf
    }
    # Collect source files
    (
        find . -name Makefile\* -o -name Kconfig\* -o -name \*.pl -o -name \*.mk
        find arch/*/include include scripts -type f -o -type l
        find security/*/include -type f
        find "arch/$arch" -name module.lds -o -name Kbuild.platforms -o -name Platform
        find $(find "arch/$arch" -name include -o -name scripts -o -name tools -type d) -type f
    ) >debian/hdrsrcfiles

    {
        # This affects arch/x86
        if is_enabled $configobj; then
            #	echo tools/objtool/objtool
            find tools/objtool -type f -executable
        fi

        find "arch/$arch/include" Module.symvers include scripts -type f

        if is_enabled CONFIG_GCC_PLUGINS; then
            find scripts/gcc-plugins -name \*.so -o -name gcc-common.h
        fi
        find tools/ -name "*e_byteshift.h"
    } >debian/hdrobjfiles

    # 检测以scrpt开头的文件，删除那些被写进.gitignore的
    process_file() {
        local input_file="$1"
        local temp_file=$(mktemp)

        while IFS= read -r line; do
            if [[ $line == scripts* ]]; then
                if ! git check-ignore -q "$line"; then
                    echo "$line" >>"$temp_file"
                fi
            else
                echo "$line" >>"$temp_file"
            fi
        done <"$input_file"

        cat "$temp_file" >"$input_file"
    }
    process_file debian/hdrsrcfiles
    process_file debian/hdrobjfiles
    echo "scripts/module.lds" >>debian/hdrsrcfiles

    tar -c -f - -C ./ -T debian/hdrsrcfiles | tar -xf - -C "$destdir"
    tar -c -f - -T debian/hdrobjfiles | tar -xf - -C "$destdir"

    # copy .config manually to be where it's expected to be
    create_dir "$tmpdir/DEBIAN"
    [[ ! -f $tmpdir/DEBIAN/postinst ]] && touch "$tmpdir/DEBIAN/postinst"
    local relseas_file="/etc/WalnutPi-release"

    cat <<EOF >"$tmpdir/DEBIAN/postinst"
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

update-initramfs -uv -k $version

EOF
    chmod +x "$tmpdir/DEBIAN/postinst"

    cat <<EOF >"$tmpdir/DEBIAN/postrm"
#!/bin/bash
if [ "\$1" = "remove" ]  ; then
    if [ -d /usr/src/linux-headers-$version ]; then
        rm -r /usr/src/linux-headers-$version
    fi
fi
EOF
    chmod +x "$tmpdir/DEBIAN/postrm"

    cp .config "$destdir/.config"
    create_dir "$tmpdir/lib/modules/$version"
    ln -s "/usr/src/linux-headers-$version" "$tmpdir/lib/modules/$version/build"
}

# 打包内核头文件
# 参数说明:
# $1 - PATH_PROJECT_DIR: 项目所在绝对路径
# $2 - SOURCE_kernel: 内核源码路径
# $3 - CHIP_ARCH: 芯片架构
# $4 - PATH_TMP: 临时路径
# $5 - LINUX_CONFIG: 内核配置
# $6 - LINUX_BRANCH: 内核分支
# $7 - BOARD_NAME: 板子名称
# $8 - OUTDIR_kernel_package: 内核包输出目录
# $9 - USE_CROSS_COMPILE: 交叉编译前缀
# $10 - LINUX_GIT: 内核Git地址
# $11 - TOOLCHAIN_FILE_NAME: 工具链文件名
# $12 - TOOLCHAIN_NAME_IN_APT: APT中的工具链名称
pack_kernel_headers() {
    local PATH_PROJECT_DIR=$1
    local SOURCE_kernel=$2
    local CHIP_ARCH=$3
    local PATH_TMP=$4
    local LINUX_CONFIG=$5
    local LINUX_BRANCH=$6
    local BOARD_NAME=$7
    local OUTDIR_kernel_package=$8
    local USE_CROSS_COMPILE=$9
    local LINUX_GIT=${10}
    local TOOLCHAIN_FILE_NAME=${11}
    local TOOLCHAIN_NAME_IN_APT=${12}
    # 输出所有传入的参数
    echo "PATH_PROJECT_DIR=$PATH_PROJECT_DIR"
    echo "SOURCE_kernel=$SOURCE_kernel"
    echo "CHIP_ARCH=$CHIP_ARCH"
    echo "PATH_TMP=$PATH_TMP"
    echo "LINUX_CONFIG=$LINUX_CONFIG"
    echo "LINUX_BRANCH=$LINUX_BRANCH"
    echo "BOARD_NAME=$BOARD_NAME"
    echo "OUTDIR_kernel_package=$OUTDIR_kernel_package"
    echo "USE_CROSS_COMPILE=$USE_CROSS_COMPILE"
    echo "LINUX_GIT=$LINUX_GIT"
    echo "TOOLCHAIN_FILE_NAME=$TOOLCHAIN_FILE_NAME"
    echo "TOOLCHAIN_NAME_IN_APT=$TOOLCHAIN_NAME_IN_APT"

    local part_name="kernel-headers"

    local TMP_KERNEL_DEB=$(_gen_tmp_package_dir "$part_name" "$PATH_TMP" "$LINUX_CONFIG" "$LINUX_BRANCH")

    local SOURCE_kernel_CLEAN="${SOURCE_kernel}-clean"
    if [ -d "$SOURCE_kernel_CLEAN" ]; then
        rm -r "$SOURCE_kernel_CLEAN"
    fi
    run_status "copy kernel" cp -r "$SOURCE_kernel" "$SOURCE_kernel_CLEAN"

    cd "$SOURCE_kernel_CLEAN"
    run_status "make the kernel clean" make clean CROSS_COMPILE="$USE_CROSS_COMPILE" ARCH="$CHIP_ARCH"

    cd "$SOURCE_kernel_CLEAN"
    local version=$(get_linux_version $SOURCE_kernel_CLEAN)
    local destdir="$TMP_KERNEL_DEB/usr/src/linux-headers-$version"
    create_dir "$destdir"
    create_dir debian

    cd "$SOURCE_kernel_CLEAN"
    make clean CROSS_COMPILE="$USE_CROSS_COMPILE" ARCH="$CHIP_ARCH"
    generate_kernel_headers "$TMP_KERNEL_DEB" "$CHIP_ARCH" "$LINUX_GIT" "$LINUX_BRANCH" \
        "$LINUX_CONFIG" "$TOOLCHAIN_FILE_NAME" "$TOOLCHAIN_NAME_IN_APT"

    _pack_as_kernel_deb "$TMP_KERNEL_DEB" "$part_name" "linux kernel header files" \
        "$BOARD_NAME" "$LINUX_BRANCH" "$CHIP_ARCH" "$PATH_PROJECT_DIR" "$SOURCE_kernel_CLEAN" "$OUTDIR_kernel_package"
}
