#!/bin/bash

menustr="walnutpi-build"
backtitle="Walnut Pi building script"


# 继续你的脚本逻辑
show_menu() {
    local title="$1"
    shift
    local options=("$@")
    TTY_X=$(($(stty size | awk '{print $2}')-6)) 			# determine terminal width
    TTY_Y=$(($(stty size | awk '{print $1}')-6)) 			# determine terminal height
    TTY_Y_WINDOW=$((TTY_Y - 8))
    if [ "$TTY_X" -le 0 ] || [ "$TTY_Y" -le 0 ] || [ "$TTY_Y_WINDOW" -le 0 ]; then
        echo -e "Error: Your terminal is too small \n"
        exit 1
    fi
    whiptail --title "${title}" --backtitle "${backtitle}" --notags \
    --menu "${menustr}" "${TTY_Y}" "${TTY_X}" ${TTY_Y_WINDOW}  \
    --cancel-button Exit --ok-button Select "${options[@]}" \
    3>&1 1>&2 2>&3
    
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
    show_menu "${titlestr}" "${options[@]}"
}

MENU_choose_parts(){
    local titlestr="Choose an option"
    local options=(
        $OPT_part_image "Full OS image for flashing"
        $OPT_part_bootloader "generate boot.bin"
        $OPT_part_kernel  "generate Kernel .deb"
        $OPT_part_rootfs "generate Rootfs .tar"
        $OPT_part_pack_rootfs "pack the tmp Rootfs files"
        $OPT_part_pack_image  "Package the output file as an image"
    )
    show_menu "${titlestr}" "${options[@]}"
}

MENU_sikp_boot(){
    local titlestr="recompile the bootloader ?"
    local options=(
        "$OPT_NO" "no"
        "$OPT_YES" "yes"
    )
    show_menu "${titlestr}" "${options[@]}"
}

MENU_sikp_kernel(){
    local titlestr="recompile the KERNEL ?"
    local options=(
        "$OPT_NO" "no"
        "$OPT_YES" "yes"
    )
    show_menu "${titlestr}" "${options[@]}"
}


MENU_choose_os() {
    # 只测试了bookworm的软件兼容性问题，有些库不确定能不能在旧版debian上运行
    titlestr="Choose an os version"
    local options=(
        ${OPT_os_debian12}    "debian 12(bookworm)"
        ${OPT_os_ubuntu22}    "ubuntu 22.04(Jammy)"
    )
    show_menu "${titlestr}" "${options[@]}"
}

MENU_choose_rootfs_type() {
    titlestr="Server or Graphics"
    options+=("$OPT_rootfs_server"    "server")
    options+=("$OPT_rootfs_desktop"    "desktop")
    show_menu "${titlestr}" "${options[@]}"
}
