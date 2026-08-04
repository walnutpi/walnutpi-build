#!/bin/bash
cd /usr/src/linux-headers-${version}

echo "Compiling headers - please wait ..."
thread_num=$(nproc)
yes "" | make -j${thread_num} ARCH=${arch} clean
find -type f -exec touch {} +
yes "" | make -j${thread_num} ARCH=${arch} oldconfig
make -j${thread_num} ARCH=${arch} -s scripts
make -j${thread_num} ARCH=${arch} -s M=scripts/mod/
echo "Compiling end"

function replace_or_append() {
    local file_path="/etc/WalnutPi-release"
    local search_string="$1"
    local replace_string="$2"

    if grep -q "^$search_string" "$file_path"; then
        sed -i "/^$search_string/c\\$replace_string" "$file_path"
    else
        echo "$replace_string" >> "$file_path"
    fi
}
replace_or_append "kernel_git" "kernel_git=${LINUX_GIT}"
replace_or_append "kernel_branch" "kernel_branch=${LINUX_BRANCH}"
replace_or_append "kernel_config" "kernel_config=${LINUX_CONFIG}"
replace_or_append "toolchain" "toolchain=${TOOLCHAIN_FILE_NAME}${TOOLCHAIN_NAME_IN_APT}"

# update-initramfs -uv -k ${version}
