#!/bin/bash
#

menustr="walnutpi-build"
backtitle="Walnut Pi building script"
TTY_X=$(($(stty size | awk '{print $2}')-6)) 			# determine terminal width
TTY_Y=$(($(stty size | awk '{print $1}')-6)) 			# determine terminal height

FLAG_menu_no_choose="no"
FLAG_OPT_NO="no"
FLAG_OPT_YES="yes"
FLAG_OPT_part_image="image"
FLAG_OPT_part_bootloader="bootloader"
FLAG_OPT_part_kernel="kernel"
FLAG_OPT_part_rootfs="rootfs"
FLAG_OPT_part_pack_rootfs="pack_rootfs"
FLAG_OPT_part_pack_image="pack_image"
FLAG_OPT_rootfs_server="server"
FLAG_OPT_rootfs_desktop="desktop"


show_menu() {
    local title="$1"
    shift
    local options=("$@")
    local result=$(whiptail --title "${title}" --backtitle "${backtitle}" --notags \
        --menu "${menustr}" "${TTY_Y}" "${TTY_X}" $((TTY_Y - 8))  \
        --cancel-button Exit --ok-button Select "${options[@]}" \
    3>&1 1>&2 2>&3)
    if [ -z $result ]; then
        exit
    fi
    echo $result
}

MENU_choose_board() {
    # 获取路径下所有文件夹名作为选项
    local path_board_list=$1
    dirs=$(find ${path_board_list} -mindepth 1 -maxdepth 1 -type d)
    local options=()
    for dir in $dirs; do
        dirname=$(basename "$dir")
        options+=("$dir" "$dirname")
    done
    local titlestr="Choose Board"
    echo $(show_menu "${titlestr}" "${options[@]}")
}

MENU_choose_parts(){
    local titlestr="Choose an option"
    local options=(
        $FLAG_OPT_part_image "Full OS image for flashing"
        $FLAG_OPT_part_bootloader "generate  boot.bin"
        $FLAG_OPT_part_kernel  "generate Kernel .deb"
        $FLAG_OPT_part_rootfs "generate Rootfs .tar"
        $FLAG_OPT_part_pack_rootfs "pack the tmp Rootfs files"
        $FLAG_OPT_part_pack_image  "pack the tmp files to generate image"
    )
    echo $(show_menu "${titlestr}" "${options[@]}")
}

MENU_sikp_boot(){
    local titlestr="recompile the bootloader ?"
    local options=(
        "$FLAG_OPT_NO" "no"
        "$FLAG_OPT_YES" "yes"
    )
    echo $(show_menu "${titlestr}" "${options[@]}")
}

MENU_sikp_kernel(){
    local titlestr="recompile the KERNEL ?"
    local options=(
        "$FLAG_OPT_NO" "no"
        "$FLAG_OPT_YES" "yes"
    )
    echo $(show_menu "${titlestr}" "${options[@]}")
}


MENU_choose_os() {
    # 只测试了bookworm的软件兼容性问题，有些库不确定能不能在旧版debian上运行
    titlestr="Choose an os version"
    local options=(
        ${FLAG_DEBIAN12_BOOKWORM}    "debian 12(bookworm)"
        ${FLAG_UBUNTU22_JAMMY}    "ubuntu 22.04(Jammy)"
    )
    echo $(show_menu "${titlestr}" "${options[@]}")
}

MENU_choose_rootfs_type() {
    titlestr="Server or Graphics"
    options+=("$FLAG_OPT_rootfs_server"    "server")
    options+=("$FLAG_OPT_rootfs_desktop"    "desktop")
    echo $(show_menu "${titlestr}" "${options[@]}")
}
